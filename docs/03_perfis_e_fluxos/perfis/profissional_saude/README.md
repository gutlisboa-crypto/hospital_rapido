# Perfil: Profissional de saúde e Enfermagem

Os dois perfis usam `StaffDashboard` (`frontend/lib/screens/staff_dashboard.dart`), mas recebem permissões e ações diferentes do backend.

## Enfermagem

- visualiza pacientes com check-in aguardando ou em triagem;
- filtra por data, especialidade, status e classificação;
- vê prioridade legal e ordenação por risco/chegada;
- registra ou revisa queixa principal, sinais vitais, classificação manual de risco e observação curta;
- só opera quando o perfil profissional está ativo e autorizado para triagem.

Esse registro é uma simulação acadêmica de fluxo e não constitui prontuário, diagnóstico ou triagem automatizada.

## Profissional de saúde

- visualiza somente a própria fila, após a etapa de enfermagem;
- vê o risco e a justificativa da prioridade usada na ordenação da fila;
- consulta detalhes do atendimento atribuído;
- chama ou chama novamente o paciente;
- inicia o atendimento quando há check-in e classificação;
- conclui o atendimento em andamento.

APIs: `/enfermagem/*` para triagem e `/medico/*` para atendimento. O perfil legado `profissional` é normalizado internamente para `medico`, sem manter rotas duplicadas.
