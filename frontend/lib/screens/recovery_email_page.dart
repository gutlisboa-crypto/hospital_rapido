part of '../main.dart';

class RecoveryPage extends StatefulWidget {
  const RecoveryPage({super.key, this.api, this.logout});
  final ApiService? api;
  final Future<void> Function()? logout;
  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  String? token;
  int step = 0, resendSeconds = 0;
  bool busy = false, hide = true;
  Timer? resendTimer;

  void startResendTimer([int seconds = 60]) {
    resendTimer?.cancel();
    setState(() => resendSeconds = seconds);
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => resendSeconds = 0);
      } else {
        setState(() => resendSeconds--);
      }
    });
  }

  Future<void> sendCode({bool resend = false}) async {
    if (!resend && !validateAndFocus(form)) return;
    setState(() => busy = true);
    try {
      final result =
          await (widget.api ?? ApiService()).forgotPassword(email.text);
      if (!mounted) return;
      notice(
          context,
          result['message'] as String? ??
              'Se o e-mail estiver cadastrado, enviaremos um código de verificação.');
      setState(() => step = 1);
      startResendTimer(result['resend_after_seconds'] as int? ?? 60);
    } on ApiException catch (e) {
      if (mounted) notice(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> next() async {
    if (step == 0) {
      await sendCode();
      return;
    }
    if (!validateAndFocus(form)) return;
    setState(() => busy = true);
    try {
      final api = widget.api ?? ApiService();
      if (step == 1) {
        token = await api.verifyRecovery(email.text, code.text);
        if (mounted) setState(() => step = 2);
      } else {
        await api.resetPassword(token!, password.text, confirmation.text);
        await (widget.logout ?? ApiService.logout)();
        if (!mounted) return;
        notice(context,
            'Senha alterada com sucesso. Faça login com sua nova senha.');
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
      }
    } on ApiException catch (e) {
      if (mounted) notice(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    email.dispose();
    code.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
      showDecorativeWaves: true,
      child: AuthLayout(
          child: Form(
              key: form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(step == 2 ? 'Definir nova senha' : 'Recuperar senha',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 27, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 20),
                    if (step == 0)
                      field(email, 'E-mail cadastrado', Icons.email_outlined,
                          requiredField: true, validator: emailRule),
                    if (step == 1) ...[
                      Semantics(
                          liveRegion: true,
                          child: const Text(
                              'Se o e-mail estiver cadastrado, enviaremos um código de verificação.')),
                      const SizedBox(height: 16),
                      field(code, 'Código de verificação', Icons.pin_outlined,
                          semanticLabel:
                              'Código de verificação de seis dígitos, obrigatório',
                          number: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6)
                          ],
                          validator: (v) =>
                              RegExp(r'^[0-9]{6}$').hasMatch(v ?? '')
                                  ? null
                                  : 'Informe os 6 números.'),
                      TextButton(
                          onPressed: busy || resendSeconds > 0
                              ? null
                              : () => sendCode(resend: true),
                          child: Text(resendSeconds > 0
                              ? 'Reenviar código em ${resendSeconds}s'
                              : 'Reenviar código')),
                    ],
                    if (step == 2) ...[
                      field(password, 'Nova senha', Icons.lock_outline,
                          requiredField: true,
                          secret: hide,
                          validator: passwordRule,
                          suffix: IconButton(
                              tooltip: hide ? 'Mostrar senha' : 'Ocultar senha',
                              onPressed: () => setState(() => hide = !hide),
                              icon: Icon(hide
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined))),
                      ValueListenableBuilder<TextEditingValue>(
                          valueListenable: password,
                          builder: (_, value, child) =>
                              PasswordRules(password: value.text)),
                      field(confirmation, 'Confirmar nova senha',
                          Icons.lock_outline,
                          requiredField: true,
                          secret: hide,
                          validator: (v) => v == password.text
                              ? null
                              : 'As senhas não conferem.'),
                    ],
                    AppActionButton(
                        label: step == 0
                            ? 'Enviar código'
                            : step == 1
                                ? 'Validar código'
                                : 'Salvar nova senha',
                        icon: step == 2
                            ? Icons.lock_reset_outlined
                            : Icons.arrow_forward,
                        onPressed: next,
                        busy: busy,
                        expand: true),
                    TextButton(
                        onPressed: busy ? null : () => Navigator.pop(context),
                        child: const Text('Voltar')),
                  ]))));
}
