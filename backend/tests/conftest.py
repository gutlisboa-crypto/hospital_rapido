"""Configuração compartilhada dos testes do backend."""

import pytest


@pytest.fixture(autouse=True)
def simulated_verification_transport(monkeypatch):
    """Never let a backend test contact a real SMTP service."""
    from app.routes import email_verification

    monkeypatch.setattr(
        email_verification,
        "send_email_verification",
        lambda _email, _code: None,
    )
