# Testes e resultados

Data da verificação: 22/10/2026 (America/Sao_Paulo).

## Backend

Comando principal:

```powershell
cd backend
.\venv\Scripts\python.exe -m pytest tests -q --basetemp=<diretório temporário>
```

Resultado final: **170 testes aprovados, 0 falhas**, em 139,63 s.

- Foi acrescentada cobertura explícita para 59 anos, aniversário de 60 anos, aniversário futuro, idoso verdadeiro, requisições adulteradas, PCD/gestante/lactante pendentes, confirmação/rejeição exclusiva da recepção, auditoria, efeito na fila, migração corretiva e seed idempotente.
- Os testes cobrem cadastro ativo e independente de SMTP, login imediato por CPF e senha, ausência de envio e de registro de verificação no cadastro, recuperação por e-mail, persistência/migração, agenda, concorrência de vaga, cancelamento/reagendamento, recepção, check-in, enfermagem, classificação manual, fila Médica, resumo obrigatório, atendimento exclusivo, administração, especialidades e permissões.
- Foram emitidos **13 avisos de depreciação**, principalmente por `datetime.utcnow()`, `FastAPI.on_event` e alias `anyio.abc.BlockingPortal`. Não causaram falhas e devem ser tratados em evolução controlada para não alterar datas nem inicialização.
- A cobertura nova valida os quatro códigos oficiais de risco, rejeita cores/texto inválido com `422`, confirma a propagação até a fila médica, verifica a ordem clínica/legal/chegada, a migração idempotente e a ausência das rotas antigas no OpenAPI.
- A recuperação por e-mail cobre resposta pública indistinguível, código correto/incorreto/expirado/usado, cinco tentativas, reenvio antes e depois de 60 segundos, token obrigatório, confirmação de senha, BCrypt e novo login.

No cadastro, o SMTP foi substituído por uma função que falharia caso fosse chamada: nenhuma tentativa ocorreu, a conta ficou ativa e o login foi aprovado. Na recuperação de senha, o envio SMTP foi simulado; nenhuma mensagem real foi enviada e nenhum segredo foi exibido.

## Flutter

```powershell
cd frontend
flutter test test/auth_responsive_test.dart test/email_verification_test.dart test/password_recovery_flow_test.dart
flutter analyze
```

- testes Flutter relacionados: **19 testes aprovados, 0 falhas**, em 16,17 s;
- `flutter analyze`: **nenhum problema encontrado**, em 4,7 s.

Os testes direcionados incluem login único, cadastro sem confirmação automática, retorno ao login, nenhuma tentativa de login automático, fluxo auxiliar preservado, recuperação completa por e-mail, proteção contra toque duplo, textos longos, larguras de 320/360/390 px, fonte A+, semântica e ondas decorativas.

## Inicialização, API e banco

- `INICIAR_TUDO.bat -Validar -SemPausa`: aprovado; ambiente `backend\venv`, Flutter e seed identificados;
- teste automatizado do iniciador: aprovado;
- API FastAPI: inicialização isolada aprovada;
- `GET /health`: `200`, status `ok`;
- Swagger `/docs`: `200`;
- OpenAPI: título `UBS Rápida API`;
- SQLite real: dados existentes preservados; arquivo alterado somente pela migração aditiva;
- migração de prioridade aplicada com `PRAGMA integrity_check = ok`, 17 usuários, 9 consultas, 2 especialidades e 230 horários preservados; backup local criado em `backend/backups/` e ignorado pelo Git;
- migração de risco executada duas vezes: **4 campos convertidos na primeira execução e 0 na segunda**; 17 usuários e 9 consultas preservados; backup `backend/backups/ubs_rapida.pre-risk-scale.bak` criado antes da conversão;
- OpenAPI verificado com 0 rotas antigas presentes; `POST /appointments` é o único método da coleção e os endpoints oficiais de calendário, recuperação, triagem e fila médica permanecem publicados;
- fluxo `check-in → triagem → fila médica → início → conclusão` aprovado em teste de integração;
- redirecionamento por perfil confirmado nos testes Flutter.

## Observações

- O cadastro não usa SMTP. A entrega real de e-mail continua necessária apenas para a recuperação de senha e depende da configuração local em `backend/.env`.
- O `.env`, SQLite local, ambientes virtuais, caches, logs e builds permanecem fora do controle de versão.
