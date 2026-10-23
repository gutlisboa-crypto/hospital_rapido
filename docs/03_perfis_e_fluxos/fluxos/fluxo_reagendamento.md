# Fluxo de reagendamento

```text
Paciente -> Minhas consultas -> Detalhes
  -> Reagendar
  -> nova especialidade/profissional/data/horário
  -> confirmação
  -> POST /appointments/{id}/reschedule
  -> API verifica propriedade, status, 12 h de antecedência e nova vaga
  -> consulta atualizada; horário anterior liberado
```
