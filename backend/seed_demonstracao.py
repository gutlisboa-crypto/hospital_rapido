"""Prepara um cenário acadêmico fictício sem apagar ou duplicar dados existentes."""

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
import unicodedata

from sqlalchemy import func, inspect, select
from sqlalchemy.exc import IntegrityError

from app.core.demo_accounts import DEMO_ACCOUNTS, DemoAccount
from app.core.config import check_config
from app.core.database import SessionLocal, engine
from app.core import clock
from app.core.security import pwd
from app.main import migrate_database
from app.services.appointments import full_age
from app.services.demo_seed import (
    ensure_canonical_demo_accounts,
    ensure_canonical_demo_schedules,
    next_weekday,
    validate_canonical_demo_accounts,
)
from app.models import (
    Appointment, AppointmentStatusHistory,
    PriorityCondition, PriorityConditionHistory, ProfessionalSchedule,
    RiskClassification, User,
)


@dataclass(frozen=True)
class WorkflowCase:
    cpf: str
    name: str
    specialty: str
    hour: int
    status: str
    risk: str | None = None
    rescheduled: bool = False
    birth_year: int = 1985
    condition: str | None = None
    condition_status: str | None = None


WORKFLOW_CASES = (
    WorkflowCase("70000000159", "Carlos Idoso Fictício", "Clínica Geral", 7, "agendado", birth_year=1950),
    WorkflowCase("70000000230", "Bianca Cancelada Fictícia", "Pediatria", 8, "cancelado"),
    WorkflowCase("70000000310", "Marina Reagendada Fictícia", "Clínica Geral", 9, "agendado", rescheduled=True),
    WorkflowCase("70000000400", "Lucas Check-in Fictício", "Pediatria", 10, "em_espera"),
    WorkflowCase("70000000582", "Joana Triagem Fictícia", "Clínica Geral", 11, "em_triagem", "moderado", condition="pcd", condition_status="pendente"),
    WorkflowCase("70000000663", "Rafael Atendimento Fictício", "Pediatria", 13, "em_atendimento", "alto", condition="gestante", condition_status="confirmada"),
    WorkflowCase("70000000744", "Camila Concluída Fictícia", "Clínica Geral", 14, "concluido", "baixo"),
)


def _available_email(db, preferred: str, cpf: str) -> str:
    if not db.scalar(select(User.id).where(func.lower(User.email) == preferred.lower())):
        return preferred
    local, domain = preferred.split("@", 1)
    candidate = f"{local}.{cpf}@{domain}"
    suffix = 2
    while db.scalar(select(User.id).where(func.lower(User.email) == candidate.lower())):
        candidate = f"{local}.{cpf}.{suffix}@{domain}"
        suffix += 1
    return candidate


def _next_weekday(start: date, amount: int = 1) -> date:
    return next_weekday(start, amount)


def ensure_demo_nursing_account() -> tuple[DemoAccount, str]:
    """Prepara a fonte canônica e retorna o estado da conta de Enfermagem."""
    account = next(item for item in DEMO_ACCOUNTS if item.role == "enfermagem")
    results = ensure_demo_accounts()
    return next(result for result in results if result[0].cpf == account.cpf)


def ensure_demo_accounts() -> list[tuple[DemoAccount, str]]:
    check_config()
    tables = set(inspect(engine).get_table_names())
    if {"usuarios", "especialidades", "perfis_profissionais"} <= tables:
        with SessionLocal() as db:
            validate_canonical_demo_accounts(db)
    migrate_database()
    with SessionLocal() as db:
        try:
            results = ensure_canonical_demo_accounts(db)
            db.commit()
            return results
        except Exception:
            db.rollback()
            raise


def ensure_demo_schedules() -> int:
    with SessionLocal() as db:
        try:
            created = ensure_canonical_demo_schedules(db)
            db.commit()
            return created
        except Exception:
            db.rollback()
            raise


def _next_demo_slot(
    db, professional: User, specialty: str, intended: datetime
) -> datetime | None:
    occupied = db.scalar(select(Appointment.id).where(
        Appointment.medico_id == professional.id,
        Appointment.data_horario == intended,
    ))
    if not occupied:
        return intended
    after = max(intended, clock.now_sao_paulo_naive())
    schedules = db.scalars(select(ProfessionalSchedule).where(
        ProfessionalSchedule.medico_id == professional.id,
        ProfessionalSchedule.data_horario > after,
        ProfessionalSchedule.bloqueado.is_(False),
    ).order_by(ProfessionalSchedule.data_horario))
    expected = "".join(
        character for character in unicodedata.normalize("NFKD", specialty.casefold())
        if character.isalnum() and not unicodedata.combining(character)
    )
    for schedule in schedules:
        scheduled = "".join(
            character for character in unicodedata.normalize(
                "NFKD", schedule.especialidade.casefold()
            )
            if character.isalnum() and not unicodedata.combining(character)
        )
        same_specialty = scheduled == expected or (
            abs(len(scheduled) - len(expected)) == 1
            and (scheduled.startswith(expected) or expected.startswith(scheduled))
        )
        if not same_specialty:
            continue
        occupied = db.scalar(select(Appointment.id).where(
            Appointment.medico_id == professional.id,
            Appointment.data_horario == schedule.data_horario,
        ))
        if not occupied:
            return schedule.data_horario
    return None


def ensure_demo_workflow() -> list[tuple[WorkflowCase, str]]:
    results: list[tuple[WorkflowCase, str]] = []
    with SessionLocal() as db:
        reception_account = next(
            account for account in DEMO_ACCOUNTS if account.role == "recepcao"
        )
        nursing_account = next(
            account for account in DEMO_ACCOUNTS if account.role == "enfermagem"
        )
        reception = db.scalar(
            select(User).where(User.cpf == reception_account.cpf)
        )
        nurse = db.scalar(select(User).where(User.cpf == nursing_account.cpf))
        professionals = {
            account.specialty: db.scalar(
                select(User).where(User.cpf == account.cpf)
            )
            for account in DEMO_ACCOUNTS
            if account.role == "medico"
        }
        if not reception or not nurse or any(value is None for value in professionals.values()):
            raise RuntimeError("As contas internas fictícias não puderam ser preparadas.")
        today = datetime.combine(clock.today_sao_paulo(), time.min)
        future = datetime.combine(_next_weekday(clock.today_sao_paulo()), time.min)
        for index, case in enumerate(WORKFLOW_CASES, start=1):
            patient = db.scalar(select(User).where(User.cpf == case.cpf))
            existing = db.scalar(select(Appointment).where(
                Appointment.paciente_id == patient.id,
                Appointment.especialidade == case.specialty,
            )) if patient else None
            if existing:
                results.append((case, "já existia; nenhum dado foi alterado"))
                continue
            intended = (
                future if case.status in {"agendado", "cancelado"} else today
            ).replace(hour=case.hour)
            scheduled_at = _next_demo_slot(
                db, professionals[case.specialty], case.specialty, intended
            )
            if scheduled_at is None:
                results.append((
                    case,
                    "aviso: sem horário futuro livre; cenário não criado",
                ))
                continue
            if not patient:
                patient = User(
                    nome=case.name, cpf=case.cpf,
                    email=_available_email(db, f"paciente.fluxo{index}@ubs-rapida.local", case.cpf),
                    senha_hash=pwd.hash("PacienteFluxo@123"), perfil="paciente", ativo=True,
                    email_verificado=True,
                    data_nascimento=datetime(case.birth_year, 1, index),
                    e_prioridade=(
                        "idoso_60+"
                        if full_age(date(case.birth_year, 1, index), clock.today_sao_paulo()) >= 60
                        else "geral"
                    ),
                    e_menor_idade=False,
                )
                db.add(patient)
                db.flush()
            # Estes CPFs pertencem exclusivamente ao seed e podem receber a
            # correção determinística sem tocar em pacientes reais.
            patient.data_nascimento = datetime(case.birth_year, 1, index)
            patient.e_prioridade = (
                "idoso_60+" if full_age(patient.data_nascimento) >= 60 else "geral"
            )
            if case.condition:
                condition = db.scalar(select(PriorityCondition).where(
                    PriorityCondition.paciente_id == patient.id,
                    PriorityCondition.condicao == case.condition,
                ))
                if not condition:
                    condition = PriorityCondition(
                        paciente_id=patient.id,
                        condicao=case.condition,
                        status=case.condition_status,
                        validada_por=reception.id if case.condition_status == "confirmada" else None,
                        validada_em=clock.now_sao_paulo_naive() if case.condition_status == "confirmada" else None,
                    )
                    db.add(condition)
                    db.flush()
                    db.add(PriorityConditionHistory(
                        condicao_prioritaria_id=condition.id,
                        status_anterior=None,
                        status_novo=case.condition_status,
                        alterado_por=reception.id if case.condition_status == "confirmada" else patient.id,
                    ))
            arrival, triaged_at = scheduled_at - timedelta(minutes=10), scheduled_at - timedelta(minutes=5)
            in_flow = case.status in {"em_espera", "em_triagem", "em_atendimento", "concluido"}
            row = Appointment(
                paciente_id=patient.id, medico_id=professionals[case.specialty].id,
                especialidade=case.specialty, data_horario=scheduled_at, status=case.status,
                chegada_em=arrival if in_flow else None, chegada_por=reception.id if in_flow else None,
                classificacao_risco=case.risk,
                triagem_dados="Observação fictícia para demonstração." if case.risk else None,
                triagem_por=nurse.id if case.risk else None,
                triagem_em=triaged_at if case.risk else None,
                chamado_em=scheduled_at if case.status in {"em_atendimento", "concluido"} else None,
                iniciado_em=scheduled_at if case.status in {"em_atendimento", "concluido"} else None,
                concluido_em=scheduled_at + timedelta(minutes=30) if case.status == "concluido" else None,
                atendimento_medico_id=(
                    professionals[case.specialty].id
                    if case.status in {"em_atendimento", "concluido"}
                    else None
                ),
                resumo_atendimento=(
                    "Resumo fictício do atendimento concluído."
                    if case.status == "concluido"
                    else None
                ),
            )
            db.add(row)
            db.flush()
            if case.risk:
                db.add(RiskClassification(
                    consulta_id=row.id, profissional_id=nurse.id,
                    nivel_risco=case.risk,
                    queixa_principal="Queixa principal fictícia.",
                    sinais_vitais="Sinais vitais fictícios estáveis.",
                    observacao=row.triagem_dados,
                    classificado_em=triaged_at,
                ))
            if case.rescheduled:
                db.add(AppointmentStatusHistory(
                    consulta_id=row.id, status_anterior="agendado",
                    status_novo="reagendado", alterado_por=patient.id,
                ))
            results.append((
                case,
                "criada" if scheduled_at == intended else "criada no próximo horário livre",
            ))
        db.commit()
    return results


def main() -> int:
    try:
        print("Contas fictícias de demonstração:")
        for account, status in ensure_demo_accounts():
            print(f"- {account.role}: {account.name} | CPF {account.cpf} | {status}.")
        print(f"Horários futuros criados: {ensure_demo_schedules()} (depois, somente os ausentes).")
        print("Cenários fictícios:")
        for case, status in ensure_demo_workflow():
            label = "reagendado" if case.rescheduled else case.status
            print(f"- {case.name}: {label} | {status}.")
        print("Swagger: http://127.0.0.1:8000/docs")
        return 0
    except (RuntimeError, IntegrityError) as exc:
        print(f"Erro: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
