"""Catálogo, gestão de horários e fluxo presencial por perfil."""
from datetime import datetime, time
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core import clock
from app.models import User, Specialty, ProfessionalSchedule, Appointment, ProfessionalProfile
from app.core.security import canonical_role, current_user, require_roles
from app.core.specialty import GENERAL_SPECIALTY, canonical_specialty_name, specialty_key
from app.schemas import CatalogItem
from app.services.appointments import active_booking_link, has_active_booking_link

router = APIRouter()
def is_general_specialty(value: str) -> bool:
    return specialty_key(value) == specialty_key(GENERAL_SPECIALTY)

class ScheduleInput(BaseModel):
    doctor_id: int
    specialty: str = Field(min_length=3, max_length=80)
    scheduled_at: datetime
    blocked: bool = False

@router.get('/specialties', response_model=list[CatalogItem])
def specialties(
    professional_id: int | None = None,
    user=Depends(current_user),
    db: Session = Depends(get_db),
):
    rows = list(db.scalars(
        select(Specialty).where(Specialty.ativo.is_(True)).order_by(Specialty.nome)
    ))
    if professional_id is not None:
        professional = db.get(User, professional_id)
        if (
            not professional
            or not professional.ativo
            or canonical_role(professional.perfil) != 'medico'
        ):
            return []
        rows = [
            row for row in rows
            if active_booking_link(db, professional_id, row.nome)
        ]
    return [{'id': row.id, 'name': canonical_specialty_name(row.nome)} for row in rows]

@router.get('/professionals', response_model=list[CatalogItem])
def professionals(specialty: str | None = None, user=Depends(current_user), db: Session = Depends(get_db)):
    rows = list(db.scalars(select(User).where(
        User.perfil.in_(['profissional', 'medico']), User.ativo.is_(True)
    ).order_by(User.nome)))
    if specialty:
        rows = [
            row for row in rows
            if active_booking_link(db, row.id, specialty)
        ]
    else:
        rows = [row for row in rows if has_active_booking_link(db, row.id)]
    return [{'id': x.id, 'name': x.nome} for x in rows]

@router.get('/schedules')
def schedules(user=Depends(require_roles('admin')), db: Session = Depends(get_db)):
    return [{'id': x.id, 'doctor_id': x.medico_id, 'specialty': canonical_specialty_name(x.especialidade), 'scheduled_at': x.data_horario, 'blocked': x.bloqueado} for x in db.scalars(select(ProfessionalSchedule).order_by(ProfessionalSchedule.data_horario))]

def validate_schedule(payload, db):
    from app.routes.admin import is_holiday
    professional = db.get(User, payload.doctor_id)
    if not professional or not professional.ativo or canonical_role(professional.perfil) != 'medico':
        raise HTTPException(422, 'Profissional inválido')
    if payload.scheduled_at.tzinfo or payload.scheduled_at <= clock.now_sao_paulo_naive():
        raise HTTPException(422, 'Informe uma data local futura')
    if payload.scheduled_at.weekday() >= 5 or is_holiday(payload.scheduled_at.date()):
        raise HTTPException(422, 'Atendimento permitido apenas em dia útil não feriado')
    if payload.scheduled_at.time().replace(second=0, microsecond=0) not in {
        time(hour, 0) for hour in (7, 8, 9, 10, 11, 13, 14, 15, 16, 17)
    }:
        raise HTTPException(422, 'Horário inválido; use 07:00–11:00 ou 13:00–17:00')
    profile = db.scalar(select(ProfessionalProfile).where(
        ProfessionalProfile.usuario_id == professional.id,
        ProfessionalProfile.ativo.is_(True)))
    if not profile or specialty_key(profile.especialidade.nome) != specialty_key(payload.specialty):
        raise HTTPException(422, 'O profissional não está vinculado à especialidade informada')

@router.post('/schedules', status_code=201)
def create_schedule(payload: ScheduleInput, user=Depends(require_roles('admin')), db: Session = Depends(get_db)):
    validate_schedule(payload, db)
    if db.scalar(select(ProfessionalSchedule).where(ProfessionalSchedule.medico_id == payload.doctor_id, ProfessionalSchedule.data_horario == payload.scheduled_at)):
        raise HTTPException(409, 'Horário já cadastrado')
    row = ProfessionalSchedule(medico_id=payload.doctor_id, especialidade=canonical_specialty_name(payload.specialty), data_horario=payload.scheduled_at, bloqueado=payload.blocked)
    db.add(row); db.commit()
    return {'id': row.id}
@router.put('/schedules/{schedule_id}')
def edit_schedule(schedule_id: int, payload: ScheduleInput, user=Depends(require_roles('admin')), db: Session = Depends(get_db)):
    row = db.get(ProfessionalSchedule, schedule_id)
    if not row: raise HTTPException(404, 'Horário não encontrado')
    validate_schedule(payload, db)
    if db.scalar(select(Appointment).where(Appointment.medico_id == row.medico_id, Appointment.data_horario == row.data_horario, Appointment.status != 'cancelado')):
        raise HTTPException(409, 'Horário ocupado não pode ser alterado')
    if db.scalar(select(ProfessionalSchedule).where(ProfessionalSchedule.id != row.id, ProfessionalSchedule.medico_id == payload.doctor_id, ProfessionalSchedule.data_horario == payload.scheduled_at)):
        raise HTTPException(409, 'Horário já cadastrado')
    row.medico_id, row.especialidade, row.data_horario, row.bloqueado = payload.doctor_id, canonical_specialty_name(payload.specialty), payload.scheduled_at, payload.blocked
    db.commit()
    return {'id': row.id}

# Fim das rotas oficiais de catálogo e agenda.
