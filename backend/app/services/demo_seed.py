"""Preparação transacional das identidades e agendas fictícias canônicas."""

from datetime import date, datetime, time, timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core import clock
from app.core.demo_accounts import DEMO_ACCOUNTS, DEMO_SPECIALTIES, DemoAccount
from app.core.security import pwd
from app.core.specialty import canonical_specialty_name
from app.models import ProfessionalProfile, ProfessionalSchedule, Specialty, User


class DemoSeedConflict(RuntimeError):
    """Colisão entre uma identidade fictícia canônica e um registro existente."""


def _conflict(account: DemoAccount, reason: str) -> DemoSeedConflict:
    return DemoSeedConflict(
        f"Conflito na conta fictícia canônica de CPF {account.cpf}: {reason}. "
        "Nenhum nome, e-mail, perfil ou senha preexistente foi substituído."
    )


def _validate_existing_user(db: Session, account: DemoAccount, user: User) -> None:
    try:
        password_matches = pwd.verify(account.password, user.senha_hash)
    except (TypeError, ValueError):
        password_matches = False
    accepted_names = (account.name, *account.legacy_names)
    accepted_emails = tuple(
        value.casefold() for value in (account.email, *account.legacy_emails)
    )
    checks = (
        (user.perfil == account.role, f"perfil esperado '{account.role}', encontrado '{user.perfil}'"),
        (user.nome in accepted_names, "nome diferente dos aliases fictícios conhecidos"),
        (user.email.strip().casefold() in accepted_emails, "e-mail diferente dos aliases fictícios conhecidos"),
        (password_matches, "credencial diferente da credencial fictícia oficial"),
        (user.ativo is True, "conta existente está desativada"),
    )
    for valid, reason in checks:
        if not valid:
            raise _conflict(account, reason)

    if not account.specialty:
        return
    profile = db.scalar(
        select(ProfessionalProfile).where(ProfessionalProfile.usuario_id == user.id)
    )
    if not profile:
        return
    profile_specialty = db.get(Specialty, profile.especialidade_id)
    expected_specialty = canonical_specialty_name(account.specialty)
    accepted_specialties = {
        expected_specialty.casefold(),
        *(value.casefold() for value in account.legacy_specialties),
    }
    if (
        profile.registro_profissional != account.registration
        or not profile_specialty
        or canonical_specialty_name(profile_specialty.nome).casefold()
        not in accepted_specialties
        or profile.ativo is not True
        or profile.autorizado_triagem != (account.role == "enfermagem")
    ):
        raise _conflict(account, "perfil profissional diferente do cadastro fictício oficial")


def _preflight(db: Session) -> dict[str, User]:
    existing: dict[str, User] = {}
    for account in DEMO_ACCOUNTS:
        user = db.scalar(select(User).where(User.cpf == account.cpf))
        if user:
            _validate_existing_user(db, account, user)
            existing[account.cpf] = user
            continue
        email_owner = db.scalar(
            select(User).where(func.lower(User.email) == account.email.casefold())
        )
        if email_owner:
            raise _conflict(account, "e-mail fictício oficial já pertence a outro CPF")
        if account.registration:
            registration_owner = db.scalar(
                select(ProfessionalProfile).where(
                    ProfessionalProfile.registro_profissional == account.registration
                )
            )
            if registration_owner:
                raise _conflict(account, "registro profissional fictício já está em uso")
    return existing


def validate_canonical_demo_accounts(db: Session) -> None:
    """Valida colisões sem escrever ou normalizar qualquer registro."""

    _preflight(db)


def ensure_canonical_demo_accounts(
    db: Session,
) -> list[tuple[DemoAccount, str]]:
    """Cria somente identidades ausentes; qualquer colisão aborta antes de escrever."""

    existing = _preflight(db)
    specialties: dict[str, Specialty] = {}
    for name in DEMO_SPECIALTIES:
        canonical = canonical_specialty_name(name)
        specialty = db.scalar(
            select(Specialty).where(
                func.lower(func.trim(Specialty.nome)) == canonical.casefold()
            )
        )
        if specialty and specialty.ativo is not True:
            raise DemoSeedConflict(
                f"Conflito na especialidade fictícia canônica '{canonical}': "
                "o registro existente está desativado. Nenhum dado foi substituído."
            )
        if not specialty:
            specialty = Specialty(nome=canonical, ativo=True)
            db.add(specialty)
            db.flush()
        specialties[canonical] = specialty

    results: list[tuple[DemoAccount, str]] = []
    for account in DEMO_ACCOUNTS:
        user = existing.get(account.cpf)
        if not user:
            user = User(
                nome=account.name,
                cpf=account.cpf,
                email=account.email,
                senha_hash=pwd.hash(account.password),
                perfil=account.role,
                ativo=True,
                email_verificado=True,
                data_nascimento=account.birth_date,
                e_prioridade="geral" if account.role == "paciente" else None,
                e_menor_idade=False,
            )
            db.add(user)
            db.flush()
            results.append((account, "criada"))
        else:
            results.append((account, "já existia; nenhum dado foi alterado"))

        if account.specialty and not db.scalar(
            select(ProfessionalProfile).where(
                ProfessionalProfile.usuario_id == user.id
            )
        ):
            specialty = specialties[canonical_specialty_name(account.specialty)]
            db.add(
                ProfessionalProfile(
                    usuario_id=user.id,
                    registro_profissional=account.registration,
                    especialidade_id=specialty.id,
                    autorizado_triagem=account.role == "enfermagem",
                    ativo=True,
                )
            )
            db.flush()
    return results


def next_weekday(start: date, amount: int = 1) -> date:
    day, found = start, 0
    while found < amount:
        day += timedelta(days=1)
        if day.weekday() < 5:
            found += 1
    return day


def ensure_canonical_demo_schedules(db: Session) -> int:
    """Cria a grade fictícia oficial sem repetir médico e horário."""

    created = 0
    for account in (item for item in DEMO_ACCOUNTS if item.role == "medico"):
        user = db.scalar(select(User).where(User.cpf == account.cpf))
        if not user:
            raise _conflict(account, "conta médica fictícia não foi preparada")
        for day_number in range(1, 6):
            day = next_weekday(clock.today_sao_paulo(), day_number)
            for hour in (7, 8, 9, 10, 11, 13, 14, 15, 16, 17):
                at = datetime.combine(day, time(hour))
                exists = db.scalar(
                    select(ProfessionalSchedule.id).where(
                        ProfessionalSchedule.medico_id == user.id,
                        ProfessionalSchedule.data_horario == at,
                    )
                )
                if exists:
                    continue
                db.add(
                    ProfessionalSchedule(
                        medico_id=user.id,
                        especialidade=account.specialty,
                        data_horario=at,
                        bloqueado=False,
                    )
                )
                created += 1
    db.flush()
    return created
