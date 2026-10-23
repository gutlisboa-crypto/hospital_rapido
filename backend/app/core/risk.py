"""Vocabulário canônico da classificação de risco da UBS."""

from typing import Final, Literal

RiskLevel = Literal["muito_alto", "alto", "moderado", "baixo"]

RISK_LEVELS: Final[tuple[str, ...]] = (
    "muito_alto",
    "alto",
    "moderado",
    "baixo",
)
RISK_LABELS: Final[dict[str, str]] = {
    "muito_alto": "Muito alto",
    "alto": "Alto",
    "moderado": "Moderado",
    "baixo": "Baixo",
}
RISK_ORDER: Final[dict[str, int]] = {
    level: position for position, level in enumerate(RISK_LEVELS)
}
RISK_COLORS: Final[dict[str, str]] = {
    "muito_alto": "#D32F2F",
    "alto": "#F57C00",
    "moderado": "#FBC02D",
    "baixo": "#388E3C",
}

# Usado exclusivamente pela migração de dados. A API nunca aceita estes valores.
LEGACY_RISK_MAPPING: Final[dict[str, str]] = {
    "vermelho": "muito_alto",
    "laranja": "alto",
    "amarelo": "moderado",
    "verde": "baixo",
    "medio": "moderado",
}
