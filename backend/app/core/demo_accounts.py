"""Fonte única das contas exclusivamente fictícias da demonstração acadêmica."""

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class DemoAccount:
    role: str
    name: str
    cpf: str
    password: str
    email: str
    specialty: str | None = None
    registration: str | None = None
    birth_date: datetime | None = None
    legacy_names: tuple[str, ...] = ()
    legacy_emails: tuple[str, ...] = ()
    legacy_specialties: tuple[str, ...] = ()


DEMO_ACCOUNTS = (
    DemoAccount(
        "admin",
        "Ana Administração Fictícia",
        "12345678909",
        "Admin@123",
        "admin.demo@ubs-rapida.local",
        legacy_names=("Admin UBS Rápida",),
    ),
    DemoAccount(
        "recepcao",
        "Rita Recepção Fictícia",
        "98765432100",
        "Recepcao@123",
        "recepcao.demo@ubs-rapida.local",
        legacy_names=("Recepção UBS Rápida",),
    ),
    DemoAccount(
        "enfermagem",
        "Enf. Helena Triagem Fictícia",
        "11144477735",
        "Profissional@123",
        "enfermagem.demo@ubs-rapida.local",
        "Clínica Geral",
        "COREN-DEMO-111",
        legacy_names=("Administrador UBS", "Profissional UBS Rápida"),
        legacy_emails=(
            "admin@ubs.local",
            "profissional.demo@ubs-rapida.local",
            "enfermagem.demo.11144477735@ubs-rapida.local",
        ),
        legacy_specialties=("Clínica gera",),
    ),
    DemoAccount(
        "medico",
        "Dr. Victor Almeida",
        "39053344705",
        "Medico@123",
        "victor.medico@ubs-rapida.local",
        "Clínica Geral",
        "CRM-DEMO-001",
        legacy_specialties=("Clínica gera",),
    ),
    DemoAccount(
        "medico",
        "Dra. Lívia Pediatria Fictícia",
        "16899535009",
        "Pediatria@123",
        "pediatria.demo@ubs-rapida.local",
        "Pediatria",
        "CRM-DEMO-002",
    ),
    DemoAccount(
        "paciente",
        "Paciente Demonstração",
        "52998224725",
        "Paciente@123",
        "paciente.demo@ubs-rapida.local",
        birth_date=datetime(1990, 1, 1),
        legacy_emails=("paciente@ubs.local",),
    ),
)

DEMO_SPECIALTIES = tuple(
    dict.fromkeys(account.specialty for account in DEMO_ACCOUNTS if account.specialty)
)

