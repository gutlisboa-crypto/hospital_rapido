"""Entrega SMTP com TLS; códigos e credenciais nunca são registrados."""

import logging
import os
import socket
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr
from email_validator import validate_email, EmailNotValidError
from app.core import clock

logger = logging.getLogger(__name__)


class MailUnavailable(Exception):
    def __init__(self, reason, *, details=None):
        self.reason = reason
        self.details = details
        super().__init__("Serviço de e-mail temporariamente indisponível.")


def delivery_error_message(reason):
    if reason in {
        "SMTP_CONFIG_MISSING",
        "SMTP_PORT_INVALID",
        "SMTP_AUTH_FAILED",
        "SMTP_DISABLED",
    }:
        return (
            "Não foi possível enviar o código de verificação agora. "
            "Confira a configuração de e-mail e tente novamente."
        )
    if reason in {"SMTP_INVALID_ADDRESS", "SMTP_RECIPIENT_REFUSED"}:
        return (
            "Não foi possível enviar o código de verificação para este endereço. "
            "Confira o e-mail informado e tente novamente."
        )
    return (
        "Não foi possível conectar com segurança ao serviço de e-mail agora. "
        "Tente novamente mais tarde."
    )


def send_recovery(email, code):
    return _send_code(
        email,
        code,
        subject="Código para recuperação de senha - UBS Rápida",
        heading="Recuperação de senha",
        purpose="recuperação",
        html=False,
    )


def send_email_verification(email, code):
    return _send_code(
        email,
        code,
        subject="Confirme seu e-mail - UBS Rápida",
        heading="Verifique seu e-mail",
        purpose="verificação do e-mail",
        html=True,
    )


def _log_failure(reason, *, error_type="none", details="none"):
    """Registra somente metadados seguros, nunca valores SMTP ou a exceção bruta."""
    logger.error(
        "email_delivery status=failed reason=%s exception_type=%s details=%s timestamp=%s",
        reason,
        error_type,
        details,
        clock.now_utc().isoformat(),
    )


def _authenticate(smtp, user, password):
    """Use one advertised mechanism so an authentication error is not masked.

    ``smtplib.login`` may try a second mechanism after an explicit 535 response.
    Some providers close that second attempt, turning the useful authentication
    error into a generic ``SMTPServerDisconnected`` exception.
    """
    advertised = getattr(smtp, "esmtp_features", {}).get("auth", "")
    mechanisms = {item.upper() for item in advertised.split()}
    if "LOGIN" in mechanisms and hasattr(smtp, "auth_login"):
        smtp.user = user
        smtp.password = password
        return smtp.auth("LOGIN", smtp.auth_login, initial_response_ok=False)
    return smtp.login(user, password)


def _send_code(email, code, *, subject, heading, purpose, html):
    try:
        enabled = os.getenv("SMTP_ENABLED", "true").strip().lower() == "true"
        if not enabled:
            raise MailUnavailable("SMTP_DISABLED")

        host = os.getenv("SMTP_HOST", "").strip()
        port_text = os.getenv("SMTP_PORT", "").strip()
        user = os.getenv("SMTP_USER", "").strip()
        password = os.getenv("SMTP_PASSWORD", "")
        sender = os.getenv("SMTP_FROM", "").strip()
        placeholders = ("COLOQUE", "COLOCAR", "PREENCHER", "_AQUI")
        configured = {
            "SMTP_HOST": host,
            "SMTP_PORT": port_text,
            "SMTP_USER": user,
            "SMTP_PASSWORD": password,
            "SMTP_FROM": sender,
        }
        invalid_fields = [
            key
            for key, value in configured.items()
            if not value.strip()
            or any(
                marker in value.upper()
                for marker in placeholders
            )
        ]
        if invalid_fields:
            raise MailUnavailable(
                "SMTP_CONFIG_MISSING", details=",".join(invalid_fields)
            )
        if os.getenv("SMTP_USE_TLS", "true").strip().lower() != "true":
            raise MailUnavailable("SMTP_TLS_REQUIRED")
        try:
            port = int(port_text)
        except ValueError:
            raise MailUnavailable("SMTP_PORT_INVALID", details="SMTP_PORT") from None
        if port not in {465, 587}:
            raise MailUnavailable("SMTP_PORT_INVALID", details="SMTP_PORT")

        sender = validate_email(sender, check_deliverability=False).normalized
        if email is not None:
            email = validate_email(email, check_deliverability=False).normalized
        context = ssl.create_default_context()
        transport = smtplib.SMTP_SSL if port == 465 else smtplib.SMTP
        options = {"timeout": 10}
        if port == 465:
            options["context"] = context
        with transport(host, port, **options) as smtp:
            if port != 465:
                smtp.ehlo()
                smtp.starttls(context=context)
                smtp.ehlo()
            _authenticate(smtp, user, password)
            # Contas desconhecidas percorrem a mesma verificação de disponibilidade.
            if email is None:
                return
            message = EmailMessage()
            message["From"] = formataddr(
                (os.getenv("SMTP_FROM_NAME", "UBS Rápida"), sender)
            )
            message["To"] = email
            message["Subject"] = subject
            message.set_content(
                f"UBS Rápida\n\nSeu código de {purpose} é {code}.\n"
                "Válido por 10 minutos e para um único uso.\n"
                "Se você não fez esta solicitação, ignore esta mensagem."
            )
            if html:
                message.add_alternative(
                    f"""<!doctype html>
<html lang="pt-BR"><body style="font-family:Arial,sans-serif;color:#212529">
<main style="max-width:560px;margin:auto;padding:24px">
<h1 style="color:#005a9c">UBS Rápida</h1>
<h2>{heading}</h2>
<p>Use o código abaixo para concluir a {purpose}:</p>
<p style="font-size:32px;font-weight:bold;letter-spacing:8px" aria-label="Código de seis dígitos">{code}</p>
<p>O código é válido por <strong>10 minutos</strong> e pode ser usado uma única vez.</p>
<p>Se você não fez esta solicitação, ignore esta mensagem.</p>
</main></body></html>""",
                    subtype="html",
                )
            if smtp.send_message(message):
                raise MailUnavailable("SMTP_RECIPIENT_REFUSED")
        logger.info(
            "email_delivery status=accepted code=SMTP_ACCEPTED timestamp=%s",
            clock.now_utc().isoformat(),
        )
    except MailUnavailable as error:
        _log_failure(error.reason, details=error.details or "none")
        raise
    except smtplib.SMTPAuthenticationError as error:
        _log_failure("SMTP_AUTH_FAILED", error_type=type(error).__name__)
        raise MailUnavailable("SMTP_AUTH_FAILED") from None
    except EmailNotValidError as error:
        _log_failure("SMTP_INVALID_ADDRESS", error_type=type(error).__name__)
        raise MailUnavailable("SMTP_INVALID_ADDRESS") from None
    except ssl.SSLError as error:
        _log_failure("SMTP_TLS_FAILED", error_type=type(error).__name__)
        raise MailUnavailable("SMTP_TLS_FAILED") from None
    except socket.gaierror as error:
        _log_failure("SMTP_DNS_FAILED", error_type=type(error).__name__)
        raise MailUnavailable("SMTP_DNS_FAILED") from None
    except (TimeoutError, socket.timeout) as error:
        _log_failure("SMTP_TIMEOUT", error_type=type(error).__name__)
        raise MailUnavailable("SMTP_TIMEOUT") from None
    except ConnectionRefusedError as error:
        _log_failure("SMTP_CONNECTION_REFUSED", error_type=type(error).__name__)
        raise MailUnavailable("SMTP_CONNECTION_REFUSED") from None
    except (OSError, smtplib.SMTPException) as error:
        _log_failure("SMTP_UNAVAILABLE", error_type=type(error).__name__)
        raise MailUnavailable("SMTP_UNAVAILABLE") from None
