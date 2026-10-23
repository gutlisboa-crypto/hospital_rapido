# API UBS Rápida

FastAPI, SQLAlchemy, SQLite persistente, JWT e BCrypt. Consulte o [índice da API](../docs/06_api/endpoints.md), a [estrutura do banco](../docs/05_banco_de_dados/estrutura_banco.md) e os [resultados de testes](../docs/07_testes/testes_e_resultados.md).

As migrações são aditivas. Não apague `ubs_rapida.db`. Execute `setup_env.py` antes da primeira inicialização e configure o SMTP em `.env` para recuperação de senha. O cadastro de pacientes cria a conta ativa sem enviar código e o primeiro login usa CPF e senha, independentemente do SMTP. As rotas auxiliares de verificação de e-mail foram preservadas por compatibilidade, mas não fazem parte do cadastro nem bloqueiam o login. Use uma senha de aplicativo do Gmail, nunca a senha normal da conta. Os códigos temporários usados na recuperação são armazenados somente como hash, expiram em 10 minutos e têm uso único.

A documentação interativa fica em `http://127.0.0.1:8000/docs` quando a API está em execução.

## SMTP para recuperação de senha

Copie `.env.example` para `.env` e preencha localmente as variáveis abaixo. O
arquivo `.env` já é ignorado pelo Git e não deve ser enviado ao repositório.

```dotenv
SMTP_ENABLED=true
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USE_TLS=true
SMTP_USER=conta-autorizada@example.com
SMTP_PASSWORD=senha-de-aplicativo
SMTP_FROM=conta-autorizada@example.com
SMTP_FROM_NAME=UBS Rápida
```

Use uma conta de teste autorizada e uma senha de aplicativo do provedor. A
aplicação exige TLS e aceita as portas `587` (STARTTLS) e `465` (TLS direto).
Não coloque credenciais em código, documentação, logs ou arquivos versionados.

Para validar manualmente, inicie a API e o Flutter, abra **Esqueceu a senha?**,
informe o endereço autorizado, aguarde o código de seis dígitos, confirme-o e
defina uma senha forte. Confirme o retorno ao login e que o código não funciona
novamente. Os testes automatizados simulam o SMTP e não enviam mensagens reais.

## Primeiro administrador

Execute somente quando ainda não existir administrador:

```powershell
cd C:\ubs_Hospital_rapido\backend
.\venv\Scripts\python.exe .\criar_admin_inicial.py
```

O cadastro público permanece exclusivo para pacientes. Recepcionistas, Enfermagem e Médicos são cadastrados pelo Painel Administrativo. Médicos usam as rotas `/medico/*`, acessam apenas a própria fila triada e concluem o atendimento com resumo obrigatório. O relatório original do painel foi preservado no [arquivo histórico](../docs/99_arquivo_historico/acervo_documentacao_projeto/PAINEL_ADMINISTRATIVO.md).

Conta Médica fictícia idempotente: CPF `39053344705`, senha `Medico@123`. O seed preserva registros preexistentes e interrompe com erro claro se um CPF canônico tiver perfil ou credencial incompatível, sem substituir dados silenciosamente.

## Política de data e hora

O módulo `app/core/clock.py` é a única fonte de horário da aplicação. UTC
é a referência para autenticação, expirações, criação/atualização e
auditoria. Regras clínicas, idade, agendas e filas usam
`America/Sao_Paulo` independentemente do fuso do sistema operacional.

Por compatibilidade, o SQLite existente não é migrado: consultas, grades e
eventos clínicos continuam como horário civil de São Paulo sem `tzinfo`; campos
técnicos legados continuam como UTC sem `tzinfo`. A API mantém o contrato atual
e não acrescenta `Z` ou offset aos horários de agendamento. A dependência
`tzdata` fornece a base IANA no Windows.
