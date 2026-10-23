# Tela da recepção

- **Nome:** Painel da Recepção.
- **Finalidade:** operar a agenda presencial do dia.
- **Perfil:** recepção.
- **Campos/filtros:** data, nome ou CPF, especialidade, profissional e status.
- **Informações:** cartões de resumo; paciente, CPF mascarado, especialidade, profissional, horário, chegada, risco e status.
- **Botões:** atualizar, buscar, detalhes, confirmar/rejeitar condição prioritária pendente, check-in, não compareceu e sair.
- **Validações:** check-in apenas no dia e em consulta agendada; ausência somente em estado compatível; ações pedem confirmação.
- **Anterior:** login.
- **Próxima:** permanece no painel com lista atualizada ou volta ao login ao sair.
- **Frontend:** `frontend/lib/screens/staff_dashboard.dart` (`StaffDashboard`).
- **API:** `GET /recepcao/resumo`, `/recepcao/agendamentos`, `/recepcao/agendamentos/{id}`; `PATCH .../check-in`, `PATCH .../nao-compareceu` e `PATCH .../condicoes/{condicao}/validacao`.
