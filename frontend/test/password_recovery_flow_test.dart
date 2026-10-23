import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubs_saude/main.dart';
import 'package:ubs_saude/services/api_service.dart';

class FakeRecoveryApi extends ApiService {
  int requests = 0, verifications = 0, resets = 0;
  String? receivedEmail, receivedCode, receivedToken;

  @override
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    requests++;
    receivedEmail = email;
    return {
      'message':
          'Se o e-mail estiver cadastrado, enviaremos um código de verificação.',
      'resend_after_seconds': 60,
    };
  }

  @override
  Future<String> verifyRecovery(String email, String code) async {
    verifications++;
    receivedEmail = email;
    receivedCode = code;
    return 'token-ficticio';
  }

  @override
  Future<void> resetPassword(
      String recoveryToken, String password, String confirmation) async {
    resets++;
    receivedToken = recoveryToken;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    accessibility.highContrast = false;
    accessibility.fontSizeScale = 1;
    accessibility.screenReaderSupport = true;
    ApiService.session = null;
  });

  testWidgets(
      'login, solicitação, código, nova senha e retorno ao login são acessíveis',
      (tester) async {
    final api = FakeRecoveryApi();
    await tester
        .pumpWidget(UbsApp(home: RecoveryPage(api: api, logout: () async {})));
    final semantics = tester.ensureSemantics();

    expect(find.bySemanticsLabel('E-mail cadastrado, obrigatório'),
        findsOneWidget);
    await tester.tap(find.text('Enviar código'));
    await tester.pump();
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(api.requests, 0);

    await tester.enterText(find.byType(TextFormField), 'email-invalido');
    await tester.tap(find.text('Enviar código'));
    await tester.pump();
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(api.requests, 0);

    await tester.enterText(
        find.byType(TextFormField), 'recuperacao@example.test');
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();
    expect(api.requests, 1);
    expect(api.receivedEmail, 'recuperacao@example.test');
    expect(
        find.bySemanticsLabel(
            'Código de verificação de seis dígitos, obrigatório'),
        findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.tap(find.text('Validar código'));
    await tester.pumpAndSettle();
    expect(api.verifications, 1);
    expect(api.receivedCode, '123456');
    expect(find.bySemanticsLabel('Nova senha, obrigatório'), findsOneWidget);
    expect(find.bySemanticsLabel('Confirmar nova senha, obrigatório'),
        findsOneWidget);
    expect(find.byType(PasswordRules), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'NovaSenha@123');
    await tester.enterText(fields.last, 'OutraSenha@123');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    expect(find.text('As senhas não conferem.'), findsOneWidget);
    expect(api.resets, 0);

    await tester.enterText(fields.last, 'NovaSenha@123');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    for (var attempt = 0;
        attempt < 20 && find.text('Acesse sua conta').evaluate().isEmpty;
        attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(api.resets, 1);
    expect(api.receivedToken, 'token-ficticio');
    expect(find.text('Acesse sua conta'), findsOneWidget);
    expect(find.text('Esqueceu a senha?'), findsOneWidget);

    semantics.dispose();
  });
}
