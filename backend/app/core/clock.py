"""Relógio único da aplicação e fronteiras das colunas SQLite legadas.

Agendamentos e eventos clínicos são persistidos como horário civil de São
Paulo sem ``tzinfo``. Eventos técnicos também usam colunas legadas sem fuso,
mas são persistidos em UTC. Os helpers ``*_naive`` existem somente para essas
fronteiras; regras novas devem preferir os valores conscientes de fuso.
"""

from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo


UTC = timezone.utc
SAO_PAULO = ZoneInfo("America/Sao_Paulo")


def now_utc() -> datetime:
    """Retorna o instante atual como ``datetime`` consciente em UTC."""

    return datetime.now(UTC)


def now_sao_paulo() -> datetime:
    """Retorna o instante atual no fuso oficial de funcionamento da UBS."""

    return now_utc().astimezone(SAO_PAULO)


def today_sao_paulo() -> date:
    """Retorna a data civil atual da UBS, nunca a data local do servidor."""

    return now_sao_paulo().date()


def now_utc_naive() -> datetime:
    """UTC sem ``tzinfo`` para colunas técnicas SQLite legadas."""

    return now_utc().replace(tzinfo=None)


def now_sao_paulo_naive() -> datetime:
    """Horário civil da UBS sem ``tzinfo`` para colunas clínicas legadas."""

    return now_sao_paulo().replace(tzinfo=None)


def utc_naive_to_sao_paulo_naive(value: datetime) -> datetime:
    """Converte UTC legado para exibição civil local sem mudar o contrato."""

    aware_utc = value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)
    return aware_utc.astimezone(SAO_PAULO).replace(tzinfo=None)
