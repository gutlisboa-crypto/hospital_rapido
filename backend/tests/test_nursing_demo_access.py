"""Regressão direcionada da conta fictícia canônica de Enfermagem."""

from sqlalchemy import func, select

from test_integration import client

from app.core.database import SessionLocal
from app.core.demo_accounts import DEMO_ACCOUNTS
from app.core.security import pwd
from app.models import ProfessionalProfile, Specialty, User
from seed_demonstracao import ensure_demo_accounts, ensure_demo_nursing_account


NURSING = next(account for account in DEMO_ACCOUNTS if account.role == "enfermagem")


def test_nursing_demo_account_is_idempotent_and_authorized(client):
    first_account, first_status = ensure_demo_nursing_account()
    second_account, second_status = ensure_demo_nursing_account()
    ensure_demo_accounts()  # mesmo caminho utilizado pelo INICIAR_TUDO.bat

    assert first_account == second_account == NURSING
    assert first_status == "criada"
    assert second_status.startswith("já existia")

    with SessionLocal() as db:
        user = db.scalar(select(User).where(User.cpf == NURSING.cpf))
        profile = db.scalar(
            select(ProfessionalProfile).where(
                ProfessionalProfile.usuario_id == user.id
            )
        )
        specialty = db.get(Specialty, profile.especialidade_id)
        assert user.ativo and user.perfil == NURSING.role
        assert user.nome == NURSING.name and user.email == NURSING.email
        assert pwd.verify(NURSING.password, user.senha_hash)
        assert profile.ativo and profile.autorizado_triagem
        assert profile.registro_profissional == NURSING.registration
        assert specialty.nome == NURSING.specialty
        assert db.scalar(
            select(func.count(User.id)).where(User.cpf == NURSING.cpf)
        ) == 1

    response = client.post(
        "/auth/login",
        json={"document": NURSING.cpf, "password": NURSING.password},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["user"]["role"] == "enfermagem"
    assert body["permissions"] == ["queue:read", "triage:write"]
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    assert client.get("/enfermagem/resumo", headers=headers).status_code == 200
    assert client.get("/admin/users", headers=headers).status_code == 403
    assert client.get("/medico/fila", headers=headers).status_code == 403
