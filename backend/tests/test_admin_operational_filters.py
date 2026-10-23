"""Filtros servidor-side das áreas operacionais administrativas."""

from datetime import datetime, timedelta

from sqlalchemy import select

from test_integration import client
from app.core import clock
from app.core.database import SessionLocal
from app.core.security import make_token, pwd
from app.models import Appointment, User


DAY = datetime(2026, 10, 21)


def _headers(user: User) -> dict[str, str]:
    return {"Authorization": f"Bearer {make_token(user)}"}


def _setup() -> dict:
    with SessionLocal() as db:
        admin = User(
            nome="Administradora Fictícia", cpf="12345678909",
            email="admin.filtros@example.test", senha_hash=pwd.hash("Admin@123"),
            perfil="admin", ativo=True,
        )
        patient_user = User(
            nome="Usuária sem permissão", cpf="98765432100",
            email="sem.permissao@example.test", senha_hash=pwd.hash("Paciente@123"),
            perfil="paciente", ativo=True,
        )
        doctor_a = User(
            nome="Dra. Ana Fictícia", cpf="11144477735",
            email="ana.filtros@example.test", senha_hash=pwd.hash("Medico@123"),
            perfil="medico", ativo=True,
        )
        doctor_b = User(
            nome="Dr. Bruno Fictício", cpf="39053344705",
            email="bruno.filtros@example.test", senha_hash=pwd.hash("Medico@123"),
            perfil="medico", ativo=True,
        )
        maria = User(
            nome="Maria Oliveira Fictícia", cpf="52998224725",
            email="maria.filtros@example.test", senha_hash=pwd.hash("Paciente@123"),
            perfil="paciente", ativo=True,
        )
        joana = User(
            nome="Joana Santos Fictícia", cpf="16899535009",
            email="joana.filtros@example.test", senha_hash=pwd.hash("Paciente@123"),
            perfil="paciente", ativo=True,
        )
        db.add_all([admin, patient_user, doctor_a, doctor_b, maria, joana])
        db.flush()
        rows = [
            Appointment(
                paciente_id=maria.id, medico_id=doctor_a.id,
                especialidade="Clínica Geral", data_horario=DAY.replace(hour=9),
                status="em_triagem", classificacao_risco="alto",
                chegada_em=DAY.replace(hour=8, minute=50),
            ),
            Appointment(
                paciente_id=joana.id, medico_id=doctor_b.id,
                especialidade="Pediatria", data_horario=DAY.replace(hour=10),
                status="em_espera", classificacao_risco="moderado",
                chegada_em=DAY.replace(hour=9, minute=45),
            ),
            Appointment(
                paciente_id=joana.id, medico_id=doctor_a.id,
                especialidade="Clínica Geral", data_horario=DAY.replace(hour=11),
                status="em_atendimento", classificacao_risco="muito_alto",
                chegada_em=DAY.replace(hour=10, minute=30),
            ),
            Appointment(
                paciente_id=maria.id, medico_id=doctor_b.id,
                especialidade="Pediatria",
                data_horario=(DAY + timedelta(days=1)).replace(hour=9),
                status="em_espera", classificacao_risco="baixo",
                chegada_em=(DAY + timedelta(days=1)).replace(hour=8, minute=50),
            ),
        ]
        db.add_all(rows)
        db.commit()
        return {
            "admin": _headers(admin),
            "patient": _headers(patient_user),
            "doctor_a": doctor_a.id,
            "ids": [row.id for row in rows],
        }


def _ids(response) -> list[int]:
    assert response.status_code == 200, response.text
    return [item["id"] for item in response.json()]


def test_admin_appointment_filters_work_individually_and_trim_values(client):
    context = _setup()
    endpoint = "/admin/appointments"
    base = {"day": "2026-10-21"}
    expected = context["ids"]

    assert set(_ids(client.get(endpoint, headers=context["admin"], params=base))) == set(expected[:3])
    assert _ids(client.get(endpoint, headers=context["admin"], params={**base, "specialty": "  Pediatria  "})) == [expected[1]]
    assert _ids(client.get(endpoint, headers=context["admin"], params={**base, "professional_id": context["doctor_a"]})) == [expected[0], expected[2]]
    assert _ids(client.get(endpoint, headers=context["admin"], params={**base, "status": " em_espera "})) == [expected[1]]
    assert _ids(client.get(endpoint, headers=context["admin"], params={**base, "risk": " alto "})) == [expected[0]]
    assert _ids(client.get(endpoint, headers=context["admin"], params={**base, "patient": "  maria oliveira  "})) == [expected[0]]

    by_cpf = client.get(
        endpoint, headers=context["admin"],
        params={**base, "patient": "529.982.247-25"},
    )
    assert _ids(by_cpf) == [expected[0]]
    assert by_cpf.json()[0]["patient_document"] == "***.***.***-25"


def test_admin_appointment_filters_use_and_and_empty_values_are_neutral(client):
    context = _setup()
    endpoint = "/admin/appointments"
    combined = client.get(endpoint, headers=context["admin"], params={
        "day": "2026-10-21", "specialty": "Clínica Geral",
        "professional_id": context["doctor_a"], "status": "em_triagem",
        "risk": "alto", "patient": "Maria",
    })
    assert _ids(combined) == [context["ids"][0]]

    empty = client.get(endpoint, headers=context["admin"], params={
        "day": "2026-10-21", "specialty": "   ", "status": " ",
        "risk": " ", "patient": "   ",
    })
    assert set(_ids(empty)) == set(context["ids"][:3])


def test_invalid_filters_permissions_and_unknown_professional_are_safe(client):
    context = _setup()
    endpoint = "/admin/appointments"
    assert client.get(endpoint, headers=context["admin"], params={"day": "data-invalida"}).status_code == 422
    assert client.get(endpoint, headers=context["admin"], params={"status": "inventado"}).status_code == 422
    assert client.get(endpoint, headers=context["admin"], params={"risk": "vermelho"}).status_code == 422
    assert client.get(endpoint, headers=context["patient"]).status_code == 403
    assert _ids(client.get(endpoint, headers=context["admin"], params={
        "day": "2026-10-21", "professional_id": 999999,
    })) == []


def test_text_search_is_parameterized_and_never_exposes_full_cpf(client):
    context = _setup()
    response = client.get(
        "/admin/appointments", headers=context["admin"],
        params={"day": "2026-10-21", "patient": "%' OR 1=1 --"},
    )
    assert _ids(response) == []
    assert "52998224725" not in response.text
    assert "16899535009" not in response.text


def test_default_date_uses_sao_paulo_when_utc_is_already_next_day(client, monkeypatch):
    context = _setup()
    monkeypatch.setattr(
        clock, "now_utc",
        lambda: datetime(2026, 10, 22, 1, 30, tzinfo=clock.UTC),
    )
    response = client.get("/admin/appointments", headers=context["admin"])
    assert set(_ids(response)) == set(context["ids"][:3])


def test_queue_combines_filters_without_changing_backend_priority_order(client):
    context = _setup()
    endpoint = "/queue"
    base = {"day": "2026-10-21"}
    original = _ids(client.get(endpoint, headers=context["admin"], params=base))
    assert original == [context["ids"][2], context["ids"][0], context["ids"][1]]

    filtered = _ids(client.get(endpoint, headers=context["admin"], params={
        **base, "specialty": " Clínica Geral ",
        "professional_id": context["doctor_a"], "patient": "a",
    }))
    assert filtered == [item for item in original if item in context["ids"][:3] and item != context["ids"][1]]
    assert _ids(client.get(endpoint, headers=context["admin"], params={**base, "risk": "alto"})) == [context["ids"][0]]
    assert _ids(client.get(endpoint, headers=context["admin"], params={**base, "status": "em_espera"})) == [context["ids"][1]]


def test_queue_invalid_values_empty_results_and_permission(client):
    context = _setup()
    assert client.get("/queue", headers=context["admin"], params={"status": "aguardando"}).status_code == 422
    assert client.get("/queue", headers=context["admin"], params={"risk": "verde"}).status_code == 422
    assert client.get("/queue", headers=context["patient"]).status_code == 403
    assert _ids(client.get("/queue", headers=context["admin"], params={
        "day": "2026-10-21", "professional_id": 999999,
    })) == []
