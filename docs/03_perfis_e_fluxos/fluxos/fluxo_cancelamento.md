# Fluxo de cancelamento

```text
Paciente -> Minhas consultas -> Detalhes
  -> Cancelar
  -> confirmação
  -> POST /appointments/{id}/cancel
  -> API verifica propriedade, status e antecedência mínima de 24 h
  -> status cancelado e vaga liberada
```
