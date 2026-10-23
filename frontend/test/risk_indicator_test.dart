import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubs_saude/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    accessibility.setContrast(false);
    accessibility.setFontScale(1);
  });

  tearDown(() {
    accessibility.setContrast(false);
    accessibility.setFontScale(1);
  });

  Future<void> pumpIndicator(WidgetTester tester, String? risk) async {
    await tester.pumpWidget(UbsApp(
        home: AppPage(child: Center(child: AppRiskIndicator(risk: risk)))));
    await tester.pumpAndSettle();
  }

  final expected = <String, (String, Color, IconData)>{
    'muito_alto': (
      'Muito alto',
      const Color(0xFFD32F2F),
      Icons.dangerous_outlined
    ),
    'alto': ('Alto', const Color(0xFFF57C00), Icons.report_problem_outlined),
    'moderado': (
      'Moderado',
      const Color(0xFFFBC02D),
      Icons.warning_amber_rounded
    ),
    'baixo': ('Baixo', const Color(0xFF2E7D32), Icons.info_outline),
  };

  for (final entry in expected.entries) {
    testWidgets('${entry.key} usa texto, cor, ícone e semântica oficiais',
        (tester) async {
      await pumpIndicator(tester, entry.key);

      expect(find.text('Risco: ${entry.value.$1}'), findsOneWidget);
      final decoration = tester
          .widget<DecoratedBox>(find.byKey(Key('risk-indicator-${entry.key}')))
          .decoration as BoxDecoration;
      expect(decoration.color, entry.value.$2);
      expect(
          tester.widget<Icon>(find.byKey(Key('risk-icon-${entry.key}'))).icon,
          entry.value.$3);
      expect(
          find.bySemanticsLabel(
              'Classificação de risco: ${entry.value.$1.toLowerCase()}'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('valor desconhecido usa estado neutro sem virar risco baixo',
      (tester) async {
    await pumpIndicator(tester, 'valor_inesperado');

    expect(find.text('Risco desconhecido'), findsOneWidget);
    expect(find.text('Risco: Baixo'), findsNothing);
    expect(find.byKey(const Key('risk-icon-unknown')), findsOneWidget);
    expect(find.bySemanticsLabel('Classificação de risco: risco desconhecido'),
        findsOneWidget);
  });

  test('risco baixo mantém contraste AA para texto normal', () {
    final presentation = RiskClassification.resolve('baixo');
    expect(
      _contrastRatio(presentation.foreground, presentation.background),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('indicador permanece identificável em alto contraste',
      (tester) async {
    accessibility.setContrast(true);
    await pumpIndicator(tester, 'muito_alto');

    final decoration = tester
        .widget<DecoratedBox>(
            find.byKey(const Key('risk-indicator-muito_alto')))
        .decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFFD32F2F));
    expect(decoration.border!.top.width, 3);
    expect(find.byKey(const Key('risk-icon-muito_alto')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('indicador não corta texto com fonte A+ em tela pequena',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    accessibility.setFontScale(1.3);
    await pumpIndicator(tester, 'muito_alto');

    expect(find.text('Risco: Muito alto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtro de risco mostra ícone, nome e cor sobre fundo claro',
      (tester) async {
    await tester.pumpWidget(const UbsApp(
        home: Scaffold(
            body: Column(children: [
      AppRiskFilterItem(risk: 'baixo'),
      AppRiskFilterItem(risk: 'moderado'),
      AppRiskFilterItem(risk: 'alto'),
      AppRiskFilterItem(risk: 'muito_alto'),
    ]))));

    final expectedColors = <String, Color>{
      'baixo': const Color(0xFF1B5E20),
      'moderado': const Color(0xFF6D4C00),
      'alto': const Color(0xFF8A3D00),
      'muito_alto': const Color(0xFFB71C1C),
    };
    for (final entry in expectedColors.entries) {
      final option = find.byKey(Key('risk-filter-option-${entry.key}'));
      final icon = find.descendant(of: option, matching: find.byType(Icon));
      final text = find.descendant(of: option, matching: find.byType(Text));
      expect(tester.widget<Icon>(icon).color, entry.value);
      expect(tester.widget<Text>(text).style?.color, entry.value);
    }
    expect(find.text('Muito alto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('triagem começa sem seleção e mantém opção selecionada legível',
      (tester) async {
    String? selected;
    await tester.pumpWidget(UbsApp(
        home: Scaffold(
            body: Form(
                child: AppRiskSelector(
                    value: selected,
                    onChanged: (value) => selected = value)))));

    expect(
        tester
            .widgetList<FilterChip>(find.byType(FilterChip))
            .every((chip) => !chip.selected),
        isTrue);
    await tester.tap(find.byKey(const Key('risk-option-alto')));
    await tester.pumpAndSettle();

    expect(selected, 'alto');
    final selectedChip =
        tester.widget<FilterChip>(find.byKey(const Key('risk-option-alto')));
    expect(selectedChip.selected, isTrue);
    expect(selectedChip.selectedColor, isNot(const Color(0xFF005A9C)));
    expect(selectedChip.labelStyle?.color, const Color(0xFF8A3D00));
    expect(find.bySemanticsLabel('Classificação de risco: alto. Selecionado'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opções da triagem podem ser escolhidas pelo teclado',
      (tester) async {
    String? selected;
    await tester.pumpWidget(UbsApp(
        home: Scaffold(
            body: Form(
                child: AppRiskSelector(
                    value: selected,
                    onChanged: (value) => selected = value)))));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(selected, 'baixo');
    expect(
        tester
            .widget<FilterChip>(find.byKey(const Key('risk-option-baixo')))
            .selected,
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordem e distribuição do risco são estáveis e responsivas',
      (tester) async {
    Future<void> pumpAt(Size size) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(UbsApp(
          home: MediaQuery(
              data: MediaQueryData(size: size),
              child: Scaffold(
                  body: Form(
                      child:
                          AppRiskSelector(value: null, onChanged: (_) {}))))));
      await tester.pumpAndSettle();
    }

    final keys = [
      const Key('risk-option-baixo'),
      const Key('risk-option-moderado'),
      const Key('risk-option-alto'),
      const Key('risk-option-muito_alto'),
    ];

    await pumpAt(const Size(900, 600));
    final wideRects =
        keys.map((key) => tester.getRect(find.byKey(key))).toList();
    expect(wideRects.map((rect) => rect.top).toSet().length, 1);
    expect(wideRects[0].left, lessThan(wideRects[1].left));
    expect(wideRects[1].left, lessThan(wideRects[2].left));
    expect(wideRects[2].left, lessThan(wideRects[3].left));

    await pumpAt(const Size(360, 640));
    final compactRects =
        keys.map((key) => tester.getRect(find.byKey(key))).toList();
    expect(compactRects[0].top, compactRects[1].top);
    expect(compactRects[2].top, compactRects[3].top);
    expect(compactRects[2].top, greaterThan(compactRects[0].top));
    expect(compactRects.map((rect) => rect.size).toSet().length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seleção e interação usam fundo claro e foco visível',
      (tester) async {
    await tester.pumpWidget(UbsApp(
        home: Scaffold(
            body: SegmentedButton<String>(segments: const [
      ButtonSegment(value: 'a', label: Text('Opção A')),
      ButtonSegment(value: 'b', label: Text('Opção B')),
    ], selected: const {
      'a'
    }, onSelectionChanged: (_) {}))));

    final context = tester.element(find.byType(SegmentedButton<String>));
    final style = Theme.of(context).segmentedButtonTheme.style!;
    expect(style.backgroundColor!.resolve({}), Colors.white);
    expect(style.backgroundColor!.resolve({WidgetState.hovered}), Colors.white);
    expect(style.backgroundColor!.resolve({WidgetState.pressed}),
        const Color(0xFFF0F6FC));
    expect(style.backgroundColor!.resolve({WidgetState.selected}),
        const Color(0xFFE8F1FF));
    expect(style.backgroundColor!.resolve({WidgetState.disabled}),
        const Color(0xFFF1F3F5));
    expect(style.foregroundColor!.resolve({WidgetState.selected}), blue);
    expect(style.side!.resolve({WidgetState.focused})!.width, 3);
  });

  testWidgets('tema global evita seleção azul-escura com texto preto',
      (tester) async {
    await tester.pumpWidget(const UbsApp(
        home: Scaffold(
            body: FilterChip(
                label: Text('Selecionado'),
                selected: true,
                onSelected: null))));
    final context = tester.element(find.byType(FilterChip));
    final theme = Theme.of(context);
    expect(theme.focusColor, const Color(0xFFE8F1FF));
    expect(theme.chipTheme.selectedColor, const Color(0xFFE8F1FF));
    expect(theme.chipTheme.secondaryLabelStyle?.color, blue);
    expect(theme.listTileTheme.selectedTileColor, const Color(0xFFE8F1FF));
    expect(theme.listTileTheme.selectedColor, blue);
  });
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  final darker = foreground.computeLuminance() > background.computeLuminance()
      ? background.computeLuminance()
      : foreground.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
