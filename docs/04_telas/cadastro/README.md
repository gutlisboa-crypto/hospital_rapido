# Telas de cadastro e confirmação de e-mail

## Cadastro do paciente

- **Finalidade:** criar exclusivamente uma conta de paciente.
- **Perfil:** público.
- **Campos:** nome completo, CPF, data de nascimento, e-mail, telefone, autodeclaração de PCD/gestante/lactante, senha e confirmação. CNS é opcional/legado e não serve para login. A confirmação de senha também é validada pela API.
- **Prioridade:** “Idoso 60+” não é selecionável; é calculado no backend pela data de nascimento. As demais condições aparecem como aguardando confirmação presencial.
- **Orientação:** “Você pode informar mais de uma condição. A prioridade somente será aplicada após confirmação presencial pela Recepção.”
- **Ações:** continuar, voltar e mostrar/ocultar senha.
- **Validações:** nome, CPF, data entre os limites aceitos, e-mail, telefone e senha forte; CPF/e-mail não podem se repetir.
- **Frontend:** `frontend/lib/screens/auth_pages.dart` (`RegisterPage`).
- **API:** `POST /auth/register`.

## Responsável legal

- **Finalidade:** coletar e vincular responsável quando o paciente é menor.
- **Campos:** nome, CPF, nascimento, parentesco, telefone e e-mail do responsável.
- **Validações:** responsável maior de idade e dados diferentes dos dados do paciente; responsáveis já existentes podem ser compartilhados de forma consistente.
- **Frontend:** `frontend/lib/screens/auth_pages.dart` (`ResponsiblePage`).
- **Próxima:** retorno à tela de login para autenticação com CPF e senha.

## Confirmação de e-mail auxiliar (compatibilidade)

- **Finalidade:** fluxo auxiliar preservado por compatibilidade; não é aberto pelo cadastro e não é requisito para o login.
- **Campos:** código de seis dígitos; opção de corrigir e-mail.
- **Ações:** validar, reenviar após o intervalo, corrigir endereço e ir ao login quando esse fluxo for aberto diretamente.
- **Frontend:** `frontend/lib/screens/email_verification_page.dart`.
- **API:** `POST /auth/email/solicitar-codigo`, `/reenviar-codigo`, `/corrigir` e `/validar-codigo`.
