import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubs_saude/main.dart';
import 'package:ubs_saude/models/api_models.dart';

Slot slot({bool selectable = true, String label = 'Disponível'}) =>
    Slot.fromJson({
      'doctor_id': 1,
      'doctor_name': 'Dra. Ana',
      'specialty': 'Pediatria',
      'scheduled_at': '2026-10-12T15:00:00',
      'availability': selectable ? 'available' : 'unavailable',
      'label': label,
      'selectable': selectable,
    });

Future<void> pumpCard(
  WidgetTester tester, {
  required Slot value,
  bool selected = false,
  VoidCallback? onPressed,
}) =>
    tester.pumpWidget(UbsApp(
      home: Scaffold(
        body: AvailabilitySlotCard(
          slot: value,
          selected: selected,
          onPressed: onPressed,
        ),
      ),
    ));

void main() {
  testWidgets('available_slot_is_actionable', (tester) async {
    var taps = 0;
    await pumpCard(tester, value: slot(), onPressed: () => taps++);

    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('Disponível'), findsOneWidget);
    expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
    expect(find.bySemanticsLabel('15:00, Disponível, 1 vaga disponível'),
        findsOneWidget);
    expect(
        tester.getSize(find.byType(InkWell)).height, greaterThanOrEqualTo(48));
    expect(
      tester
          .getSemantics(find.byType(AvailabilitySlotCard))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );

    await tester.tap(find.byType(AvailabilitySlotCard));
    expect(taps, 1);
  });

  testWidgets('unavailable_slot_never_invokes_callback', (tester) async {
    var taps = 0;
    await pumpCard(
      tester,
      value: slot(selectable: false, label: 'Já agendado'),
      onPressed: () => taps++,
    );

    expect(find.text('Indisponível'), findsOneWidget);
    expect(find.text('Já agendado'), findsOneWidget);
    expect(find.byIcon(Icons.event_busy_outlined), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byType(AvailabilitySlotCard))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    await tester.tap(find.byType(AvailabilitySlotCard));
    expect(taps, 0);
  });

  testWidgets('selected_slot_has_check_and_semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCard(tester, value: slot(), selected: true, onPressed: () {});

    expect(find.text('Selecionado'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(
      find.bySemanticsLabel('15:00, Selecionado, 1 vaga disponível'),
      findsOneWidget,
    );
    final selectedLabel = tester.widget<Text>(find.text('Selecionado'));
    final context = tester.element(find.byType(AvailabilitySlotCard));
    expect(selectedLabel.style?.color, Theme.of(context).colorScheme.primary);
    semantics.dispose();
  });

  testWidgets('slot_states_survive_high_contrast', (tester) async {
    accessibility.setContrast(true);
    addTearDown(() => accessibility.setContrast(false));

    await pumpCard(
      tester,
      value: slot(selectable: false, label: 'Indisponível'),
      onPressed: () {},
    );

    expect(find.text('Indisponível'), findsOneWidget);
    expect(find.byIcon(Icons.event_busy_outlined), findsOneWidget);
    final decorated =
        tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
  });

  testWidgets('slot longo permanece legível em largura estreita e A+',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    accessibility.setFontScale(1.3);
    addTearDown(() => accessibility.setFontScale(1));

    await pumpCard(
      tester,
      value: slot(selectable: false, label: 'Indisponível para agendamento'),
      onPressed: () {},
    );

    expect(find.text('Indisponível para agendamento'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legenda usa as mesmas cores semânticas dos horários',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AvailabilityLegend())));

    final context = tester.element(find.byType(AvailabilityLegend));
    final colors = Theme.of(context).colorScheme;
    expect(tester.widget<Text>(find.text('Disponível')).style?.color, green);
    expect(tester.widget<Text>(find.text('Indisponível')).style?.color,
        colors.error);
    expect(tester.widget<Text>(find.text('Selecionado')).style?.color,
        colors.primary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('horário disponível mantém contraste AA', (tester) async {
    await pumpCard(tester, value: slot(), onPressed: () {});

    final card = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = card.decoration as BoxDecoration;
    final label = tester.widget<Text>(find.text('Disponível'));
    expect(
      _contrastRatio(label.style!.color!, decoration.color!),
      greaterThanOrEqualTo(4.5),
    );
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
