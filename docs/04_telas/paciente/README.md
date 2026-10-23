# Telas do paciente

## Dashboard

- **Finalidade:** reunir próxima consulta, consultas do paciente, dados pessoais e atalhos.
- **Perfil:** paciente.
- **Ações:** atualizar, abrir agendamento, ver detalhes, cancelar, reagendar, alterar/recuperar senha, ajustar acessibilidade e sair.
- **Navegação:** vem do login; abre o painel de agendamento e diálogos de detalhes/confirmação.
- **Frontend:** `frontend/lib/screens/dashboards.dart` (`PatientDashboard`, `StatusTimeline`).
- **API:** `GET /patients/me`, `/patients/me/summary`, `/appointments/me` e `/appointments/{id}`.

## Agendamento e reagendamento

- **Finalidade:** selecionar especialidade, profissional, data e horário e confirmar o resumo.
- **Perfil:** paciente autenticado.
- **Campos:** seletores encadeados de especialidade, profissional e data; horários em botões selecionáveis.
- **Ações:** fechar, tentar novamente, confirmar agendamento ou confirmar novo horário.
- **Validações:** opções vêm da API; horário precisa permanecer disponível no momento da confirmação.
- **Anterior/próxima:** dashboard -> painel de agendamento -> dashboard atualizado.
- **Frontend:** `frontend/lib/screens/booking.dart` (`BookingPanel`).
- **API:** `GET /specialties`, `/professionals`, `/availability/calendar-dates`, `/availability/calendar-times`; `POST /appointments` e `/appointments/{id}/reschedule`.

## Detalhes da consulta

- **Finalidade:** mostrar profissional, especialidade, data, status e linha do tempo.
- **Ações:** fechar, cancelar ou reagendar quando as regras de prazo e status permitem.
- **API:** `GET /appointments/{id}`, `POST /appointments/{id}/cancel` e `/reschedule`.
