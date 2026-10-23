"""Regression contract for 401 authentication and 403 authorization responses."""

import base64
import json
from datetime import timedelta

import pytest
from jose import jwt

from test_integration import client
from app.core import clock
from app.core.config import ALGORITHM, SECRET
from app.core.database import SessionLocal
from app.core.security import make_token, pwd
from app.models import User


PROFILE_ROUTES = {
    "paciente": "/patients/me",
    "recepcao": "/recepcao/resumo",
    "enfermagem": "/enfermagem/resumo",
    "medico": "/medico/fila",
    "admin": "/admin/summary",
}


def _users():
    with SessionLocal() as db:
        result = {}
        for index, role in enumerate(PROFILE_ROUTES, start=1):
            user = User(
                nome=f"Usuário {role.title()}",
                cpf=f"80000000{index:03d}",
                email=f"{role}@example.test",
                senha_hash=pwd.hash("Equipe@123"),
                perfil=role,
                ativo=True,
                email_verificado=True,
            )
            db.add(user)
            db.flush()
            result[role] = user.id
        db.commit()
        return result


@pytest.mark.parametrize("endpoint", PROFILE_ROUTES.values())
@pytest.mark.parametrize(
    "headers",
    [
        {},
        {"Authorization": "Bearer"},
        {"Authorization": "Bearer malformed"},
    ],
)
def test_protected_routes_reject_missing_empty_and_malformed_tokens(
    client, endpoint, headers
):
    response = client.get(endpoint, headers=headers)
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


def test_expired_tampered_and_revoked_tokens_return_401(client):
    ids = _users()
    with SessionLocal() as db:
        patient = db.get(User, ids["paciente"])
        valid = make_token(patient)
        expired = jwt.encode(
            {
                "sub": str(patient.id),
                "purpose": "access",
                "version": patient.token_version,
                "role": "paciente",
                "exp": clock.now_utc() - timedelta(seconds=1),
            },
            SECRET,
            algorithm=ALGORITHM,
        )
    def unsigned_part(value: dict) -> str:
        raw = json.dumps(value, separators=(",", ":")).encode()
        return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()

    alg_none = ".".join([
        unsigned_part({"alg": "none", "typ": "JWT"}),
        unsigned_part({
            "sub": str(ids["paciente"]),
            "purpose": "access",
            "version": 0,
            "role": "paciente",
            "exp": int((clock.now_utc() + timedelta(hours=1)).timestamp()),
        }),
        "",
    ])
    tokens = [
        expired,
        f"{valid[:-1]}{'a' if valid[-1] != 'a' else 'b'}",
        alg_none,
    ]
    for token in tokens:
        response = client.get(
            "/patients/me", headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 401
        assert response.headers["www-authenticate"] == "Bearer"

    with SessionLocal() as db:
        patient = db.get(User, ids["paciente"])
        patient.token_version += 1
        db.commit()
    revoked = client.get(
        "/patients/me", headers={"Authorization": f"Bearer {valid}"}
    )
    assert revoked.status_code == 401
    assert revoked.headers["www-authenticate"] == "Bearer"


@pytest.mark.parametrize("role,endpoint", PROFILE_ROUTES.items())
def test_authenticated_wrong_profile_stays_403(client, role, endpoint):
    ids = _users()
    wrong_role = "admin" if role != "admin" else "recepcao"
    with SessionLocal() as db:
        token = make_token(db.get(User, ids[wrong_role]))
    response = client.get(endpoint, headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 403


def test_public_registration_requires_matching_password_confirmation(client):
    payload = {
        "name": "Paciente Contrato",
        "cpf": "52998224725",
        "birth_date": "1990-03-15",
        "email": "contrato@example.com",
        "phone": "11999998888",
        "password": "Paciente@123",
        "password_confirmation": "Diferente@123",
    }
    mismatched = client.post("/auth/register", json=payload)
    assert mismatched.status_code == 422
    assert mismatched.json()["detail"]["field"] == "password_confirmation"

    payload.pop("password_confirmation")
    missing = client.post("/auth/register", json=payload)
    assert missing.status_code == 422
