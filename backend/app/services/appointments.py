"""Regras compartilhadas do fluxo presencial de consultas."""
from datetime import date, datetime, timedelta
import json

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import (
    Appointment,
    AppointmentStatusHistory,
    AuditLog,
    ProfessionalProfile,
    ProfessionalSchedule,
    Specialty,
    User,
)
from app.core.security import canonical_role
from app.core.specialty import canonical_specialty_name, specialty_key
from app.core.risk import RISK_ORDER
from app.core import clock


LEGAL_PRIORITY_ORDER = {
    "idoso_60+": 0,
    "pcd": 1,
    "gestante": 2,
    "lactante": 3,
    "geral": 4,
}
LEGAL_PRIORITY_LABELS = {
    "idoso_60+": "Pessoa idosa (60 anos ou mais)",
    "pcd": "Pessoa com deficiência (PCD)",
    "gestante": "Gestante",
    "lactante": "Lactante",
    "geral": "Sem prioridade legal",
}

VALIDATABLE_CONDITIONS = ("pcd", "gestante", "lactante")

_SENSITIVE_AUDIT_KEYS = (
    "senha", "password", "hash", "token", "cpf", "email", "queixa",
    "diagnostico", "diagnóstico", "sinais_vitais", "observacao",
    "observação", "resumo",
)


def record_audit_event(
    db: Session,
    actor: User,
    action: str,
    kind: str,
    record_id: int | None,
    details: dict | None = None,
) -> None:
    """Registra uma ação sem copiar dados pessoais ou clínicos para o texto."""
    safe = {
        key: value for key, value in (details or {}).items()
        if not any(term in key.casefold() for term in _SENSITIVE_AUDIT_KEYS)
    }
    safe.setdefault("perfil_responsavel", canonical_role(actor.perfil))
    db.add(AuditLog(
        usuario_id=actor.id,
        acao=action,
        tipo_registro=kind,
        registro_id=record_id,
        detalhes=json.dumps(safe, ensure_ascii=False),
    ))


def active_booking_link(db: Session, doctor_id: int, specialty_name: str) -> bool:
    """Confirma o vínculo ativo usado por catálogo, disponibilidade e reserva.

    Agendas antigas sem perfil profissional continuam compatíveis somente quando
    apontam para uma especialidade ativa. Se há perfil, ele é a autoridade do
    vínculo e precisa estar ativo e corresponder à especialidade.
    """
    doctor = db.get(User, doctor_id)
    if (
        not doctor
        or not doctor.ativo
        or canonical_role(doctor.perfil) != "medico"
    ):
        return False
    specialty = db.scalar(select(Specialty).where(
        Specialty.ativo.is_(True),
        func.lower(func.trim(Specialty.nome))
        == canonical_specialty_name(specialty_name).lower(),
    ))
    if not specialty:
        return False
    profile = db.scalar(select(ProfessionalProfile).where(
        ProfessionalProfile.usuario_id == doctor_id
    ))
    if profile:
        return bool(
            profile.ativo and profile.especialidade_id == specialty.id
        )
    return db.scalar(select(ProfessionalSchedule.id).where(
        ProfessionalSchedule.medico_id == doctor_id,
        func.lower(func.trim(ProfessionalSchedule.especialidade))
        == canonical_specialty_name(specialty.nome).lower(),
    )) is not None


def has_active_booking_link(db: Session, doctor_id: int) -> bool:
    doctor = db.get(User, doctor_id)
    if (
        not doctor
        or not doctor.ativo
        or canonical_role(doctor.perfil) != "medico"
    ):
        return False
    profile = db.scalar(select(ProfessionalProfile).where(
        ProfessionalProfile.usuario_id == doctor_id
    ))
    if profile:
        specialty = db.get(Specialty, profile.especialidade_id)
        return bool(profile.ativo and specialty and specialty.ativo)
    active_names = {
        specialty_key(name)
        for name in db.scalars(select(Specialty.nome).where(
            Specialty.ativo.is_(True)
        ))
    }
    return any(
        specialty_key(name) in active_names
        for name in db.scalars(select(ProfessionalSchedule.especialidade).where(
            ProfessionalSchedule.medico_id == doctor_id
        ))
    )


def full_age(birth_date: date | datetime, today: date | None = None) -> int:
    """Calcula idade completa; esta é a única regra de idade do domínio."""
    born = birth_date.date() if isinstance(birth_date, datetime) else birth_date
    today = today or clock.today_sao_paulo()
    return today.year - born.year - ((today.month, today.day) < (born.month, born.day))


def confirmed_conditions(patient: User) -> set[str]:
    return {
        item.condicao for item in patient.condicoes_prioritarias
        if item.status == "confirmada" and item.condicao in VALIDATABLE_CONDITIONS
    }


def legal_priority_code(patient: User, today: date | None = None) -> str:
    if patient.data_nascimento and full_age(patient.data_nascimento, today) >= 60:
        return "idoso_60+"
    confirmed = confirmed_conditions(patient)
    return next((name for name in VALIDATABLE_CONDITIONS if name in confirmed), "geral")


def is_legal_priority(patient: User, today: date | None = None) -> bool:
    return legal_priority_code(patient, today) != "geral"


def legal_priority_label(patient: User, today: date | None = None) -> str:
    code = legal_priority_code(patient, today)
    if code == "idoso_60+":
        return f"Pessoa idosa — {full_age(patient.data_nascimento, today)} anos"
    if code != "geral":
        return f"{LEGAL_PRIORITY_LABELS[code]} — confirmado presencialmente"
    pending = next((
        item.condicao for item in patient.condicoes_prioritarias
        if item.status == "pendente" and item.condicao in VALIDATABLE_CONDITIONS
    ), None)
    return (
        f"{LEGAL_PRIORITY_LABELS[pending]} — confirmação pendente"
        if pending else LEGAL_PRIORITY_LABELS["geral"]
    )


def queue_sort_key(item: Appointment):
    patient = item.paciente
    confirmed = confirmed_conditions(patient)
    elderly = bool(
        patient.data_nascimento and full_age(patient.data_nascimento) >= 60
    )
    return (
        RISK_ORDER.get(item.classificacao_risco, len(RISK_ORDER)),
        0 if elderly else 1,
        0 if "pcd" in confirmed else 1,
        0 if "gestante" in confirmed else 1,
        0 if "lactante" in confirmed else 1,
        item.chegada_em or datetime.max,
        item.id,
    )


def register_manual_absence(
    db: Session,
    appointment: Appointment,
    actor: User,
    now: datetime | None = None,
) -> Appointment:
    """Registra falta manual somente após 15 minutos e antes do check-in."""
    now = now or clock.now_sao_paulo_naive()
    if (
        appointment.status != "agendado"
        or appointment.chegada_em is not None
        or appointment.falta_em is not None
    ):
        raise HTTPException(409, "Somente consulta agendada e sem check-in pode receber falta")
    if appointment.data_horario.date() != now.date():
        raise HTTPException(409, "A falta manual só pode ser registrada no dia da consulta")
    if now < appointment.data_horario + timedelta(minutes=15):
        raise HTTPException(
            409,
            "A falta só pode ser registrada após 15 minutos do horário da consulta",
        )

    appointment.status = "falta"
    appointment.falta_em = now
    db.add(AppointmentStatusHistory(
        consulta_id=appointment.id,
        status_anterior="agendado",
        status_novo="falta",
        alterado_por=actor.id,
    ))
    record_audit_event(
        db,
        actor,
        "falta_registrada",
        "consulta",
        appointment.id,
        {"status_anterior": "agendado", "status_novo": "falta"},
    )
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise
    return appointment


def mark_overdue_absences(db: Session, actor: User, now: datetime | None = None) -> int:
    """Marca como falta consultas sem chegada 15 minutos após o horário.

    A alteração fica vinculada ao usuário interno que provocou a atualização,
    preservando a trilha de auditoria sem criar uma credencial de sistema.
    """
    now = now or clock.now_sao_paulo_naive()
    limit = now - timedelta(minutes=15)
    rows = list(db.scalars(select(Appointment).where(
        Appointment.status == "agendado",
        Appointment.chegada_em.is_(None),
        Appointment.falta_em.is_(None),
        Appointment.data_horario <= limit,
    )))
    for row in rows:
        row.status = "falta"
        row.falta_em = now
        db.add(AppointmentStatusHistory(
            consulta_id=row.id,
            status_anterior="agendado",
            status_novo="falta",
            alterado_por=actor.id,
        ))
        record_audit_event(
            db,
            actor,
            "falta_automatica",
            "consulta",
            row.id,
            {
                "status_anterior": "agendado",
                "status_novo": "falta",
                "regra": "atraso_minimo_15_minutos",
            },
        )
    if rows:
        db.commit()
    return len(rows)
