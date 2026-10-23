"""Canonical presentation and comparison helpers for specialties."""

import unicodedata


GENERAL_SPECIALTY = "Clínica Geral"
_GENERAL_SPECIALTY_KEYS = frozenset(("clinica geral", "clinica gera"))


def _comparison_key(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", " ".join(value.split()).casefold())
    return "".join(char for char in normalized if not unicodedata.combining(char))


def canonical_specialty_name(value: str) -> str:
    """Preserve arbitrary names while canonicalizing legacy General Clinic variants."""
    trimmed = " ".join(value.split())
    if _comparison_key(trimmed) in _GENERAL_SPECIALTY_KEYS:
        return GENERAL_SPECIALTY
    return trimmed


def specialty_storage_name(value: str) -> str:
    """Normalize new canonical spellings without rewriting the known truncated legacy value."""
    trimmed = " ".join(value.split())
    if _comparison_key(trimmed) == "clinica geral":
        return GENERAL_SPECIALTY
    return trimmed


def specialty_key(value: str) -> str:
    return _comparison_key(canonical_specialty_name(value))
