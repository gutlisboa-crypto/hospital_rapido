from datetime import timedelta
import hashlib
import hmac
import bcrypt
from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy import delete
from sqlalchemy.orm import Session
from app.core.config import SECRET, ALGORITHM
from app.core.database import get_db
from app.core import clock
from app.models import User, RateLimit


class PasswordHasher:
    def hash(self, value):
        return bcrypt.hashpw(value.encode(), bcrypt.gensalt()).decode()

    def verify(self, value, encoded):
        try:
            return bcrypt.checkpw(value.encode(), encoded.encode())
        except (ValueError, TypeError):
            return False


pwd = PasswordHasher()
DUMMY_HASH = pwd.hash("Unrelated-Dummy@123")
security = HTTPBearer(auto_error=False)

ROLE_PERMISSIONS = {
    "paciente": ["appointments:own", "profile:own"],
    "admin": [
        "users:manage", "professionals:manage", "specialties:manage",
        "schedules:manage", "appointments:read", "appointments:checkin",
        "queue:read", "audit:read",
    ],
    "recepcao": ["appointments:read", "appointments:checkin", "queue:read"],
    "enfermagem": ["queue:read", "triage:write"],
    "medico": ["appointments:assigned", "queue:read", "care:update"],
}


def canonical_role(role: str) -> str:
    return "medico" if role == "profissional" else role


def permissions_for(user: User) -> list[str]:
    return list(ROLE_PERMISSIONS.get(canonical_role(user.perfil), []))


def digest(value):
    return hmac.new(SECRET.encode(), value.encode(), hashlib.sha256).hexdigest()


def make_token(user):
    return jwt.encode(
        {
            "sub": str(user.id),
            "purpose": "access",
            "version": user.token_version,
            "role": canonical_role(user.perfil),
            "exp": clock.now_utc() + timedelta(hours=8),
        },
        SECRET,
        algorithm=ALGORITHM,
    )


def make_email_verification_token(user):
    return jwt.encode(
        {
            "sub": str(user.id),
            "purpose": "email_verification_setup",
            "exp": clock.now_utc() + timedelta(minutes=30),
        },
        SECRET,
        algorithm=ALGORITHM,
    )


def current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    db: Session = Depends(get_db),
):
    unauthorized = HTTPException(
        401,
        "Sessão inválida ou expirada",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None or not credentials.credentials.strip():
        raise unauthorized
    try:
        data = jwt.decode(credentials.credentials, SECRET, algorithms=[ALGORITHM])
        if data.get("purpose") != "access":
            raise ValueError()
        user = db.get(User, int(data["sub"]))
        if not user or not user.ativo or data.get("version") != user.token_version:
            raise ValueError()
        return user
    except (JWTError, KeyError, ValueError, TypeError):
        raise unauthorized


def require_roles(*roles):
    def checker(user=Depends(current_user)):
        if user.perfil not in roles and canonical_role(user.perfil) not in roles:
            raise HTTPException(403, "Seu perfil não possui autorização para esta ação")
        return user

    return checker


def throttle(db, request: Request, action, identifier, limit=10):
    """Contadores persistentes por IP e documento, sem armazenar identificadores brutos."""
    now = clock.now_utc_naive()
    db.execute(delete(RateLimit).where(RateLimit.expires_at <= now))
    for scope, value, maximum in [
        ("ip", request.client.host if request.client else "local", limit * 5),
        ("document", identifier, limit),
    ]:
        key = digest(f"{action}:{scope}:{value}")
        row = db.get(RateLimit, key)
        if row and row.attempts >= maximum:
            db.commit()
            raise HTTPException(
                429, "Muitas tentativas. Aguarde 15 minutos e tente novamente."
            )
        if row:
            row.attempts += 1
        else:
            db.add(
                RateLimit(key=key, attempts=1, expires_at=now + timedelta(minutes=15))
            )
    db.commit()
    return row.attempts if row else 1
