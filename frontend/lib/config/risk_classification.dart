part of '../main.dart';

@immutable
class RiskPresentation {
  const RiskPresentation({
    required this.code,
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.order,
  });

  final String? code;
  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;
  final int order;

  String get semanticLabel => 'Classificação de risco: ${label.toLowerCase()}';
}

/// Única definição da escala clínica usada pela interface.
abstract final class RiskClassification {
  static const values = <String>[
    'baixo',
    'moderado',
    'alto',
    'muito_alto',
  ];
  static const presentations = <String, RiskPresentation>{
    'muito_alto': RiskPresentation(
      code: 'muito_alto',
      label: 'Muito alto',
      background: Color(0xFFD32F2F),
      foreground: Colors.white,
      icon: Icons.dangerous_outlined,
      order: 3,
    ),
    'alto': RiskPresentation(
      code: 'alto',
      label: 'Alto',
      background: Color(0xFFF57C00),
      foreground: Colors.black,
      icon: Icons.report_problem_outlined,
      order: 2,
    ),
    'moderado': RiskPresentation(
      code: 'moderado',
      label: 'Moderado',
      background: Color(0xFFFBC02D),
      foreground: Colors.black,
      icon: Icons.warning_amber_rounded,
      order: 1,
    ),
    'baixo': RiskPresentation(
      code: 'baixo',
      label: 'Baixo',
      background: Color(0xFF2E7D32),
      foreground: Colors.white,
      icon: Icons.info_outline,
      order: 0,
    ),
  };

  static const _notInformed = RiskPresentation(
    code: null,
    label: 'Risco não informado',
    background: Color(0xFFE0E0E0),
    foreground: Color(0xFF212121),
    icon: Icons.help_outline,
    order: 4,
  );
  static const _unknown = RiskPresentation(
    code: null,
    label: 'Risco desconhecido',
    background: Color(0xFFE0E0E0),
    foreground: Color(0xFF212121),
    icon: Icons.help_outline,
    order: 4,
  );
  static final Set<String> _reportedUnexpectedValues = <String>{};

  static Map<String, String> get labels => {
        for (final entry in presentations.entries) entry.key: entry.value.label,
      };

  static Map<String, int> get order => {
        for (final entry in presentations.entries) entry.key: entry.value.order,
      };

  static Map<String, Color> get colors => {
        for (final entry in presentations.entries)
          entry.key: entry.value.background,
      };

  static List<(String, String)> get options =>
      [for (final value in values) (value, presentations[value]!.label)];

  static RiskPresentation resolve(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return _notInformed;
    final presentation = presentations[normalized];
    if (presentation != null) return presentation;
    if (_reportedUnexpectedValues.add(normalized)) {
      debugPrint(
          'Valor inesperado de classificação de risco recebido: $normalized');
    }
    return _unknown;
  }

  static String label(String? value) => resolve(value).label;
}
