# Telas da Enfermagem e do Profissional

## Painel da Enfermagem

- **Finalidade:** acompanhar pacientes com check-in e registrar classificação manual.
- **Perfil:** enfermagem autorizada.
- **Filtros:** data, especialidade, status e classificação.
- **Botões:** atualizar, detalhes, classificar/reclassificar risco e sair.
- **Diálogo:** nível (muito alto, alto, moderado ou baixo), queixa principal e sinais vitais obrigatórios, além de observação curta opcional.
- **Validações:** exige check-in, estado compatível e autorização ativa.
- **Frontend:** `frontend/lib/screens/staff_dashboard.dart` (`StaffDashboard`, `_RiskDialog`).
- **API:** `GET /enfermagem/resumo`, `/fila`, `/agendamentos/{id}`; `PATCH .../classificacao-risco`.

## Painel do Profissional de Saúde

- **Finalidade:** operar os atendimentos atribuídos ao profissional autenticado.
- **Perfil:** profissional (alias legado `medico`).
- **Campos/filtros:** data e status; detalhes são somente leitura e mostram risco, queixa, sinais vitais e justificativa da prioridade.
- **Botões:** atualizar, detalhes, chamar/chamar novamente, iniciar, concluir e sair.
- **Validações:** consulta deve pertencer ao profissional; início exige check-in e classificação; conclusão exige atendimento em andamento.
- **Frontend:** `frontend/lib/screens/staff_dashboard.dart`.
- **API médica oficial:** `GET /medico/fila`, `/medico/atendimentos/{id}`; `PATCH .../chamar`, `/iniciar` e `/concluir`.
