# Perfil: Paciente

## Acesso e painel

O paciente entra pelo login único com CPF e senha assim que conclui o cadastro; não há confirmação obrigatória de e-mail. Após autenticação, o backend retorna `perfil = paciente` e o Flutter abre `PatientDashboard` (`frontend/lib/screens/dashboards.dart`).

O painel mostra saudação, próxima consulta, atalhos, lista de consultas e dados pessoais. Há atualização automática de status, acessibilidade, alteração/recuperação de senha e saída.

## Agendamento

Em `BookingPanel` (`frontend/lib/screens/booking.dart`), o paciente seleciona especialidade, profissional, data e horário livre, revisa o resumo e confirma. A API valida disponibilidade e propriedade. O resultado aparece na lista e no resumo do painel.

## Cancelamento e reagendamento

Nos detalhes da consulta, o paciente pode cancelar até 24 horas antes ou reagendar até 12 horas antes. A vaga anterior é liberada quando a operação é válida. Consultas em outro status não podem ser alteradas por esse fluxo.

## Acompanhamento

O paciente acompanha os estados agendada, check-in realizado, em triagem, em atendimento, concluída, cancelada ou falta. Ele não altera diretamente estados do fluxo presencial.

APIs principais: `/auth/login`, `/patients/me`, `/patients/me/summary`, `/appointments/me`, `/specialties`, `/professionals`, `/availability/*` e `/appointments`.
