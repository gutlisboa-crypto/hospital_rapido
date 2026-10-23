"""Regressões do relógio central e da virada do dia da UBS."""

from datetime import datetime

from app.core import clock
from app.services.appointments import full_age


def test_clock_returns_aware_utc_and_sao_paulo_for_same_instant():
    utc = clock.now_utc()
    local = utc.astimezone(clock.SAO_PAULO)

    assert utc.tzinfo is clock.UTC
    assert local.tzinfo is clock.SAO_PAULO
    assert utc == local
    assert local.utcoffset() is not None


def test_legacy_helpers_are_explicitly_naive():
    assert clock.now_utc_naive().tzinfo is None
    assert clock.now_sao_paulo_naive().tzinfo is None


def test_legacy_utc_audit_time_is_converted_for_local_display():
    stored = datetime(2026, 10, 22, 1, 30)
    assert clock.utc_naive_to_sao_paulo_naive(stored) == datetime(
        2026, 10, 21, 22, 30
    )


def test_sao_paulo_date_does_not_advance_with_utc(monkeypatch):
    fixed_utc = datetime(2026, 10, 22, 1, 30, tzinfo=clock.UTC)
    monkeypatch.setattr(clock, "now_utc", lambda: fixed_utc)

    local = clock.now_sao_paulo()
    assert local == datetime(2026, 10, 21, 22, 30, tzinfo=clock.SAO_PAULO)
    assert clock.today_sao_paulo().isoformat() == "2026-10-21"
    assert datetime(2026, 10, 21, 14).date() == clock.today_sao_paulo()
    assert datetime(2026, 10, 22, 8) > clock.now_sao_paulo_naive()


def test_sao_paulo_date_advances_at_local_midnight(monkeypatch):
    fixed_utc = datetime(2026, 10, 22, 3, 30, tzinfo=clock.UTC)
    monkeypatch.setattr(clock, "now_utc", lambda: fixed_utc)

    assert clock.now_sao_paulo() == datetime(
        2026, 10, 22, 0, 30, tzinfo=clock.SAO_PAULO
    )
    assert clock.today_sao_paulo().isoformat() == "2026-10-22"


def test_age_changes_only_on_sao_paulo_birthday(monkeypatch):
    monkeypatch.setattr(
        clock,
        "now_utc",
        lambda: datetime(2026, 10, 22, 1, 30, tzinfo=clock.UTC),
    )
    assert full_age(datetime(1966, 10, 22)) == 59

    monkeypatch.setattr(
        clock,
        "now_utc",
        lambda: datetime(2026, 10, 22, 3, 30, tzinfo=clock.UTC),
    )
    assert full_age(datetime(1966, 10, 22)) == 60
