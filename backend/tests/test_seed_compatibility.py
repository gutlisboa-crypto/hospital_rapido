"""Compatibilidade, aliases legados e atomicidade dos seeds fictícios."""

import pytest
from sqlalchemy import func, select

from test_integration import client

from app.core.database import SessionLocal
from app.core.demo_accounts import DEMO_ACCOUNTS, DEMO_SPECIALTIES
from app.core.security import pwd
from app.main import seed
from app.models import (
    Appointment,
    ProfessionalProfile,
    ProfessionalSchedule,
    Specialty,
    User,
)
from app.services.demo_seed import DemoSeedConflict
from seed_demonstracao import (
    WORKFLOW_CASES,
    ensure_demo_accounts,
    ensure_demo_schedules,
    ensure_demo_workflow,
)


NURSING = next(
    account for account in DEMO_ACCOUNTS if account.role == "enfermagem"
)


def _minimal_seed() -> None:
    with SessionLocal() as db:
        seed(db)


def _full_seed() -> None:
    ensure_demo_accounts()
    ensure_demo_schedules()
    ensure_demo_workflow()


def _counts() -> tuple[int, ...]:
    with SessionLocal() as db:
        return tuple(
            db.scalar(select(func.count(model.id)))
            for model in (
                User,
                Specialty,
                ProfessionalProfile,
                ProfessionalSchedule,
                Appointment,
            )
        )


def _insert_nursing_account(
    *,
    name: str | None = None,
    email: str | None = None,
    password: str | None = None,
    role: str | None = None,
    registration: str | None = None,
    specialty_name: str | None = None,
    can_triage: bool = True,
) -> None:
    with SessionLocal() as db:
        specialty_value = specialty_name or NURSING.specialty
        specialty = db.scalar(
            select(Specialty).where(Specialty.nome == specialty_value)
        )
        if not specialty:
            specialty = Specialty(nome=specialty_value, ativo=True)
            db.add(specialty)
            db.flush()
        user = User(
            nome=name or NURSING.name,
            cpf=NURSING.cpf,
            email=email or NURSING.email,
            senha_hash=pwd.hash(password or NURSING.password),
            perfil=role or NURSING.role,
            ativo=True,
            email_verificado=True,
        )
        db.add(user)
        db.flush()
        db.add(
            ProfessionalProfile(
                usuario_id=user.id,
                registro_profissional=registration or NURSING.registration,
                especialidade_id=specialty.id,
                autorizado_triagem=can_triage,
                ativo=True,
            )
        )
        db.commit()


def _nursing_snapshot() -> tuple[object, ...]:
    with SessionLocal() as db:
        user = db.scalar(select(User).where(User.cpf == NURSING.cpf))
        profile = db.scalar(
            select(ProfessionalProfile).where(
                ProfessionalProfile.usuario_id == user.id
            )
        )
        specialty = db.get(Specialty, profile.especialidade_id)
        return (
            user.id,
            user.nome,
            user.email,
            user.senha_hash,
            user.perfil,
            user.ativo,
            user.atualizado_em,
            profile.id,
            profile.registro_profissional,
            specialty.nome,
            profile.autorizado_triagem,
            profile.ativo,
        )


def _assert_unique_accounts_and_active_admin() -> None:
    with SessionLocal() as db:
        duplicates = db.execute(
            select(User.cpf)
            .group_by(User.cpf)
            .having(func.count(User.id) > 1)
        ).all()
        admin = db.scalar(
            select(User).where(User.perfil == "admin", User.ativo.is_(True))
        )
        assert duplicates == []
        assert admin is not None


def _assert_canonical_state(client) -> None:
    with SessionLocal() as db:
        for account in DEMO_ACCOUNTS:
            users = db.scalars(select(User).where(User.cpf == account.cpf)).all()
            assert len(users) == 1
            user = users[0]
            assert (user.nome, user.email, user.perfil, user.ativo) == (
                account.name,
                account.email,
                account.role,
                True,
            )
            assert pwd.verify(account.password, user.senha_hash)
            profile = db.scalar(
                select(ProfessionalProfile).where(
                    ProfessionalProfile.usuario_id == user.id
                )
            )
            if account.specialty:
                assert profile is not None
                specialty = db.get(Specialty, profile.especialidade_id)
                assert specialty.nome == account.specialty
                assert profile.registro_profissional == account.registration
                assert profile.autorizado_triagem == (account.role == "enfermagem")
                assert profile.ativo is True
            else:
                assert profile is None

        for name in DEMO_SPECIALTIES:
            assert db.scalar(
                select(func.count(Specialty.id)).where(Specialty.nome == name)
            ) == 1

        duplicated_profiles = db.execute(
            select(ProfessionalProfile.usuario_id)
            .group_by(ProfessionalProfile.usuario_id)
            .having(func.count(ProfessionalProfile.id) > 1)
        ).all()
        duplicated_schedules = db.execute(
            select(
                ProfessionalSchedule.medico_id,
                ProfessionalSchedule.data_horario,
            )
            .group_by(
                ProfessionalSchedule.medico_id,
                ProfessionalSchedule.data_horario,
            )
            .having(func.count(ProfessionalSchedule.id) > 1)
        ).all()
        assert duplicated_profiles == []
        assert duplicated_schedules == []
        assert db.scalar(select(func.count(Appointment.id))) == len(WORKFLOW_CASES)

    for account in DEMO_ACCOUNTS:
        response = client.post(
            "/auth/login",
            json={"document": account.cpf, "password": account.password},
        )
        assert response.status_code == 200
        assert response.json()["user"]["role"] == account.role


def test_empty_minimal_then_full_seed(client):
    _minimal_seed()
    _full_seed()
    _assert_canonical_state(client)
    _assert_unique_accounts_and_active_admin()


def test_empty_full_then_minimal_seed(client):
    _full_seed()
    _minimal_seed()
    _assert_canonical_state(client)
    _assert_unique_accounts_and_active_admin()


def test_full_seed_twice_keeps_all_counts(client):
    _full_seed()
    first_counts = _counts()
    _full_seed()
    assert _counts() == first_counts
    _assert_canonical_state(client)
    _assert_unique_accounts_and_active_admin()


def test_exact_canonical_account_is_accepted_without_mutation(client):
    _insert_nursing_account()
    before = _nursing_snapshot()
    ensure_demo_accounts()
    assert _nursing_snapshot() == before


def test_known_legacy_email_is_accepted_without_mutation(client):
    _insert_nursing_account(email=NURSING.legacy_emails[-1])
    before = _nursing_snapshot()
    ensure_demo_accounts()
    assert _nursing_snapshot() == before
    _assert_unique_accounts_and_active_admin()


def test_known_legacy_name_is_accepted_without_mutation(client):
    _insert_nursing_account(name=NURSING.legacy_names[-1])
    before = _nursing_snapshot()
    ensure_demo_accounts()
    assert _nursing_snapshot() == before


def test_known_legacy_specialty_is_accepted_without_mutation(client):
    _insert_nursing_account(specialty_name=NURSING.legacy_specialties[0])
    before = _nursing_snapshot()
    ensure_demo_accounts()
    assert _nursing_snapshot() == before


@pytest.mark.parametrize(
    ("overrides", "expected_reason"),
    (
        ({"password": "SenhaDiferente@123"}, "credencial diferente"),
        ({"role": "medico"}, "perfil esperado"),
        ({"email": "desconhecido@example.test"}, "e-mail diferente"),
        ({"registration": "COREN-DESCONHECIDO"}, "perfil profissional diferente"),
    ),
    ids=("different-password", "different-role", "unknown-email", "invalid-profile-link"),
)
def test_incompatible_identity_or_professional_link_is_rejected_without_mutation(
    client, overrides, expected_reason
):
    _insert_nursing_account(**overrides)
    before = _nursing_snapshot()
    before_counts = _counts()
    with pytest.raises(DemoSeedConflict, match=expected_reason):
        ensure_demo_accounts()
    assert _nursing_snapshot() == before
    assert _counts() == before_counts


def test_incompatible_canonical_cpf_aborts_without_mutation(client):
    canonical = next(
        account for account in DEMO_ACCOUNTS if account.role == "enfermagem"
    )
    with SessionLocal() as db:
        conflicting = User(
            nome="Registro preexistente preservado",
            cpf=canonical.cpf,
            email="preexistente@example.test",
            senha_hash=pwd.hash("SenhaPreexistente@123"),
            perfil="profissional",
            ativo=True,
            email_verificado=True,
        )
        unrelated = User(
            nome="Outro registro preservado",
            cpf="45678912364",
            email="outro@example.test",
            senha_hash=pwd.hash("OutraSenha@123"),
            perfil="paciente",
            ativo=True,
            email_verificado=True,
        )
        db.add_all((conflicting, unrelated))
        db.commit()
        before = {
            row.cpf: (
                row.nome,
                row.email,
                row.senha_hash,
                row.perfil,
                row.ativo,
                row.token_version,
                row.e_prioridade,
                row.atualizado_em,
            )
            for row in db.scalars(select(User)).all()
        }
        before_counts = (
            db.scalar(select(func.count(Specialty.id))),
            db.scalar(select(func.count(ProfessionalProfile.id))),
            db.scalar(select(func.count(ProfessionalSchedule.id))),
            db.scalar(select(func.count(Appointment.id))),
        )

    try:
        ensure_demo_accounts()
    except DemoSeedConflict as exc:
        message = str(exc)
    else:
        raise AssertionError("O seed deveria recusar o CPF canônico incompatível")

    assert "Conflito na conta fictícia canônica" in message
    assert "perfil esperado" in message
    assert "Nenhum nome, e-mail, perfil ou senha" in message
    with SessionLocal() as db:
        after = {
            row.cpf: (
                row.nome,
                row.email,
                row.senha_hash,
                row.perfil,
                row.ativo,
                row.token_version,
                row.e_prioridade,
                row.atualizado_em,
            )
            for row in db.scalars(select(User)).all()
        }
        assert after == before
        assert (
            db.scalar(select(func.count(Specialty.id))),
            db.scalar(select(func.count(ProfessionalProfile.id))),
            db.scalar(select(func.count(ProfessionalSchedule.id))),
            db.scalar(select(func.count(Appointment.id))),
        ) == before_counts
