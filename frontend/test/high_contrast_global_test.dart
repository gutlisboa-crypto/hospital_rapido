import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubs_saude/main.dart';
import 'package:ubs_saude/models/api_models.dart';
import 'package:ubs_saude/services/api_service.dart';

class _DashboardApi extends ApiService {
  @override
  Future<PatientSummary> summary() async => PatientSummary.fromJson({
        'patient': {
          'name': 'Maria da Silva',
          'masked_cpf': '***.***.***-25',
          'birth_date': '1990-01-01',
          'email': 'maria@example.com',
          'phone': '(11) 99999-9999',
        },
        'next_appointment': null,
      });

  @override
  Future<List<Appointment>> appointments() async => [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    accessibility.highContrast = false;
    accessibility.fontSizeScale = 1;
    ApiService.session = null;
  });

  final pages = <String, Widget Function()>{
    'Login': () => const LoginPage(),
    'Cadastro': () => const RegisterPage(),
    'Responsável Legal': () => const ResponsiblePage(patientData: {
          'name': 'Paciente Menor',
          'cpf': '52998224725',
          'phone': '11999999999',
          'email': 'paciente@example.com',
        }),
    'Recuperação': () => const RecoveryPage(),
    'Dashboard': () => PatientDashboard(api: _DashboardApi()),
  };

  for (final entry in pages.entries) {
    testWidgets(
        '${entry.key} acompanha o estado global desligado, ligado e desligado',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(UbsApp(home: entry.value()));
      await tester.pump();
      _expectContrast(tester, enabled: false);

      accessibility.setContrast(true);
      await tester.pump();
      _expectContrast(tester, enabled: true);

      accessibility.setContrast(false);
      await tester.pump();
      _expectContrast(tester, enabled: false);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('controle do menu atualiza toda a tela sem reiniciar',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const UbsApp());
    _expectContrast(tester, enabled: false);

    await tester.tap(find.text('Preferências de acessibilidade'));
    await tester.pump();
    final contrastSwitch =
        find.widgetWithText(SwitchListTile, 'Alto contraste');
    await tester.tap(contrastSwitch);
    await tester.pump();
    _expectContrast(tester, enabled: true);

    tester.widget<SwitchListTile>(contrastSwitch).onChanged!(false);
    await tester.pump();
    _expectContrast(tester, enabled: false);
  });
}

void _expectContrast(WidgetTester tester, {required bool enabled}) {
  final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
  expect(
      scaffold.backgroundColor, enabled ? Colors.black : pageBackgroundColor);

  final painters = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<WavePainter>()
      .toList();
  expect(painters.every((painter) => painter.highContrast == enabled), isTrue);

  final theme = Theme.of(tester.element(find.byType(Scaffold).first));
  expect(theme.scaffoldBackgroundColor,
      enabled ? Colors.black : pageBackgroundColor);
  expect(theme.inputDecorationTheme.fillColor,
      enabled ? Colors.black : Colors.white);
}
