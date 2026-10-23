# Fluxo de cadastro

```text
Login -> Criar conta
  -> dados do paciente
  -> se menor: dados do responsável legal
  -> POST /auth/register
  -> conta paciente ativa
  -> retorno à tela de login
  -> login com CPF e senha
  -> painel do paciente
```

Por decisão de escopo e usabilidade do projeto acadêmico, o cadastro não chama o transporte SMTP nem cria registro de verificação. Uma indisponibilidade de e-mail não impede a criação da conta ou o primeiro login. A recuperação de senha permanece separada e continua exigindo código enviado por e-mail, armazenado somente como hash, com tentativas limitadas e uso único.
