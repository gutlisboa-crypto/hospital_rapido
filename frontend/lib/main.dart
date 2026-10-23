import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'models/api_models.dart';
import 'widgets/brand_mark.dart';
part 'screens/recovery_email_page.dart';
part 'screens/booking.dart';
part 'config/accessibility.dart';
part 'config/design_system.dart';
part 'config/risk_classification.dart';
part 'widgets/app_components.dart';
part 'widgets/responsive_shell.dart';
part 'widgets/shared_widgets.dart';
part 'widgets/password_rules.dart';
part 'screens/dashboards.dart';
part 'screens/staff_dashboard.dart';
part 'screens/medical_dashboard.dart';
part 'screens/admin_dashboard.dart';
part 'screens/auth_pages.dart';
part 'screens/email_verification_page.dart';

const blue = Color(0xFF005A9C);
// Verde semântico com contraste AA sobre superfícies claras.
const green = Color(0xFF176B3A);
const pageBackgroundColor = Color(0xFFF8F9FA);
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await accessibility.load();
  await ApiService.restoreSession();
  runApp(const UbsApp());
}

class UbsApp extends StatelessWidget {
  const UbsApp({super.key, this.home});
  final Widget? home;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: accessibility,
      builder: (_, __) {
        final contrast = accessibility.highContrast,
            fg = contrast ? Colors.yellow : const Color(0xFF212529);
        final segmentedStyle = ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return contrast ? Colors.black : const Color(0xFFF1F3F5);
            }
            if (states.contains(WidgetState.selected)) {
              return contrast ? Colors.yellow : const Color(0xFFE8F1FF);
            }
            if (states.contains(WidgetState.pressed)) {
              return contrast ? Colors.white24 : const Color(0xFFF0F6FC);
            }
            return contrast ? Colors.black : Colors.white;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return contrast ? Colors.white54 : const Color(0xFF6C757D);
            }
            if (contrast && states.contains(WidgetState.selected)) {
              return Colors.black;
            }
            return contrast ? Colors.yellow : blue;
          }),
          overlayColor: WidgetStatePropertyAll(
            contrast ? Colors.white12 : const Color(0x14005A9C),
          ),
          side: WidgetStateProperty.resolveWith((states) => BorderSide(
                color: contrast
                    ? (states.contains(WidgetState.focused)
                        ? Colors.white
                        : Colors.yellow)
                    : blue,
                width: states.contains(WidgetState.focused) ? 3 : 1.5,
              )),
        );
        return MaterialApp(
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            debugShowCheckedModeBanner: false,
            title: 'UBS Rápida',
            themeAnimationDuration: Duration.zero,
            theme: ThemeData(
                useMaterial3: true,
                scaffoldBackgroundColor: accessibility.pageBackground,
                colorScheme: ColorScheme.fromSeed(
                    seedColor: blue,
                    brightness: contrast ? Brightness.dark : Brightness.light,
                    primary: contrast ? Colors.yellow : blue,
                    onPrimary: contrast ? Colors.black : Colors.white,
                    surface: contrast ? Colors.black : null,
                    onSurface: contrast ? Colors.white : null),
                focusColor: contrast ? Colors.white : const Color(0xFFE8F1FF),
                hoverColor: contrast ? Colors.white12 : const Color(0xFFF0F6FC),
                highlightColor:
                    contrast ? Colors.white24 : const Color(0xFFE8F1FF),
                iconTheme:
                    IconThemeData(color: contrast ? Colors.yellow : null),
                dividerColor: contrast ? Colors.yellow : null,
                cardTheme: CardThemeData(
                    color: contrast ? Colors.black : Colors.white,
                    elevation: contrast ? 0 : 2,
                    shadowColor:
                        contrast ? Colors.transparent : const Color(0x1A1E293B),
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        side: BorderSide(
                            color: contrast
                                ? Colors.yellow
                                : const Color(0xFFE1E7ED),
                            width: contrast ? 2 : 1),
                        borderRadius: BorderRadius.circular(18))),
                chipTheme: ChipThemeData(
                    backgroundColor: contrast ? Colors.black : Colors.white,
                    selectedColor:
                        contrast ? Colors.yellow : const Color(0xFFE8F1FF),
                    disabledColor: contrast
                        ? const Color(0xFF222222)
                        : const Color(0xFFF1F3F5),
                    labelStyle: TextStyle(color: fg),
                    secondaryLabelStyle:
                        TextStyle(color: contrast ? Colors.black : blue),
                    side: BorderSide(
                        color: contrast ? Colors.yellow : blue, width: 1.5),
                    checkmarkColor: contrast ? Colors.black : blue),
                listTileTheme: ListTileThemeData(
                    selectedColor: contrast ? Colors.black : blue,
                    selectedTileColor:
                        contrast ? Colors.yellow : const Color(0xFFE8F1FF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                filledButtonTheme: FilledButtonThemeData(
                    style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(Size(
                            AppSizes.minTouchTarget, AppSizes.minTouchTarget)),
                        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md)),
                        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadii.control))),
                        textStyle: const WidgetStatePropertyAll(TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                        backgroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.disabled)) {
                            return contrast
                                ? const Color(0xFF242424)
                                : const Color(0xFFDCE2E8);
                          }
                          if (states.contains(WidgetState.pressed)) {
                            return contrast
                                ? Colors.white
                                : const Color(0xFF00477C);
                          }
                          return contrast ? Colors.yellow : blue;
                        }),
                        foregroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.disabled)) {
                            return contrast
                                ? Colors.white70
                                : const Color(0xFF4F5963);
                          }
                          return contrast ? Colors.black : Colors.white;
                        }),
                        side: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.focused)) {
                            return BorderSide(
                                color: contrast
                                    ? Colors.white
                                    : const Color(0xFF003B66),
                                width: 3);
                          }
                          if (states.contains(WidgetState.disabled)) {
                            return BorderSide(
                                color: contrast
                                    ? Colors.white70
                                    : const Color(0xFF9AA4AE));
                          }
                          return BorderSide.none;
                        }))),
                outlinedButtonTheme: OutlinedButtonThemeData(
                    style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(Size(
                            AppSizes.minTouchTarget, AppSizes.minTouchTarget)),
                        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md)),
                        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadii.control))),
                        textStyle: const WidgetStatePropertyAll(
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.disabled)) {
                            return contrast
                                ? const Color(0xFF181818)
                                : const Color(0xFFF1F3F5);
                          }
                          if (states.contains(WidgetState.pressed)) {
                            return contrast
                                ? Colors.white24
                                : const Color(0xFFE8F1FF);
                          }
                          if (states.contains(WidgetState.hovered)) {
                            return contrast
                                ? Colors.white12
                                : const Color(0xFFF0F6FC);
                          }
                          return contrast ? Colors.black : Colors.white;
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.disabled)) {
                            return contrast
                                ? Colors.white70
                                : const Color(0xFF5F6973);
                          }
                          return contrast ? Colors.yellow : blue;
                        }),
                        side: WidgetStateProperty.resolveWith((states) => BorderSide(
                            color: contrast
                                ? (states.contains(WidgetState.focused) ? Colors.white : Colors.yellow)
                                : states.contains(WidgetState.disabled)
                                    ? const Color(0xFF9AA4AE)
                                    : blue,
                            width: states.contains(WidgetState.focused) ? 3 : 1.5)))),
                textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
                segmentedButtonTheme: SegmentedButtonThemeData(style: segmentedStyle),
                iconButtonTheme: const IconButtonThemeData(style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size.square(AppSizes.minTouchTarget)))),
                textTheme: TextTheme(headlineSmall: TextStyle(color: fg, fontSize: 30, height: 1.15, fontWeight: FontWeight.w800), titleLarge: TextStyle(color: fg, fontSize: 22, height: 1.25, fontWeight: FontWeight.w700), titleMedium: TextStyle(color: fg, fontSize: 18, height: 1.3), bodyLarge: TextStyle(color: fg, fontSize: 16, height: 1.45), bodyMedium: TextStyle(color: fg, fontSize: 16, height: 1.4), bodySmall: TextStyle(color: fg, fontSize: 14, height: 1.35), labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: contrast ? Colors.black : Colors.white, labelStyle: TextStyle(color: fg), hintStyle: TextStyle(color: contrast ? Colors.white : Colors.grey), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: contrast ? Colors.yellow : Colors.grey, width: contrast ? 3 : 1)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: contrast ? Colors.white : blue, width: 3))),
                snackBarTheme: contrast ? const SnackBarThemeData(backgroundColor: Colors.yellow, contentTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.w700), actionTextColor: Colors.black) : const SnackBarThemeData(),
                navigationBarTheme: contrast ? const NavigationBarThemeData(backgroundColor: Colors.black, indicatorColor: Colors.yellow, iconTheme: WidgetStatePropertyAll(IconThemeData(color: Colors.white)), labelTextStyle: WidgetStatePropertyAll(TextStyle(color: Colors.white))) : NavigationBarThemeData(indicatorColor: const Color(0xFFE8F1FF), labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(color: states.contains(WidgetState.selected) ? blue : const Color(0xFF212529), fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500)))),
            builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(accessibility.fontSizeScale)), child: child ?? const SizedBox.shrink()),
            home: home ?? (ApiService.session == null ? const LoginPage() : homeForRole()));
      });
}

Widget homeForRole() => switch (ApiService.session!.role) {
      'paciente' => const PatientDashboard(),
      'admin' => const AdminDashboard(),
      'recepcao' => const StaffDashboard(),
      'enfermagem' => const StaffDashboard(),
      'medico' => const MedicalDashboard(),
      'profissional' => const MedicalDashboard(),
      _ => const LoginPage(),
    };

String digits(String value) => value.replaceAll(RegExp(r'\D'), '');
bool strongPassword(String value) =>
    value.length >= 8 &&
    value.length <= 32 &&
    value.contains(RegExp(r'[A-Z]')) &&
    value.contains(RegExp(r'[a-z]')) &&
    value.contains(RegExp(r'[0-9]')) &&
    value.contains(RegExp(r'[^A-Za-z0-9]'));
String showDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} às ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Formats a specialty only for presentation, preserving the canonical value
/// used by API requests and database relationships.
String specialtyDisplayName(String value) {
  final trimmed = value.trim();
  return switch (trimmed.toLowerCase()) {
    'clínica geral' ||
    'clinica geral' ||
    'clínica gera' ||
    'clinica gera' =>
      'Clínica Geral',
    _ => trimmed,
  };
}

List<Map<String, dynamic>> uniqueSpecialtyOptions(
    Iterable<Map<String, dynamic>> values) {
  final seen = <String>{};
  return [
    for (final value in values)
      if (seen.add(specialtyDisplayName(value['name'] as String).toLowerCase()))
        value,
  ];
}

void announceImportant(BuildContext context, String text) {
  if (!accessibility.screenReaderSupport) return;
  SemanticsService.sendAnnouncement(
      View.of(context), text, Directionality.of(context));
}

void notice(BuildContext c, String text, {bool announce = true}) {
  ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(content: Semantics(container: true, child: Text(text))));
  if (announce) announceImportant(c, text);
}

class CpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final d = digits(newValue.text)
        .substring(0, digits(newValue.text).length.clamp(0, 11).toInt());
    final text = d.length <= 3
        ? d
        : d.length <= 6
            ? '${d.substring(0, 3)}.${d.substring(3)}'
            : d.length <= 9
                ? '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6)}'
                : '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final d = digits(newValue.text)
        .substring(0, digits(newValue.text).length.clamp(0, 11).toInt());
    final text = d.length <= 2
        ? d
        : d.length <= 6
            ? '(${d.substring(0, 2)}) ${d.substring(2)}'
            : d.length <= 10
                ? '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}'
                : '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

bool isValidCpf(String value) {
  final cpf = digits(value);
  if (!RegExp(r'^\d{11}$').hasMatch(cpf) ||
      RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) {
    return false;
  }
  int check(int length) {
    final sum =
        List.generate(length, (i) => int.parse(cpf[i]) * (length + 1 - i))
            .reduce((a, b) => a + b);
    final result = (sum * 10) % 11;
    return result == 10 ? 0 : result;
  }

  return check(9) == int.parse(cpf[9]) && check(10) == int.parse(cpf[10]);
}

String? requiredName(String? v) {
  final value = (v ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  return RegExp(r'^[A-Za-zÀ-ÖØ-öø-ÿ]+(?:[- ][A-Za-zÀ-ÖØ-öø-ÿ]+)+$')
              .hasMatch(value) &&
          value.length >= 3 &&
          value.length <= 80
      ? null
      : 'Informe nome e sobrenome, apenas letras.';
}

String? requiredCpf(String? v) =>
    isValidCpf(v ?? '') ? null : 'CPF inválido. Confira os 11 números.';
String? emailRule(String? v) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v ?? '')
        ? null
        : 'Informe um e-mail válido.';
String? phoneRule(String? v) => [10, 11].contains(digits(v ?? '').length)
    ? null
    : 'Telefone deve ter 10 ou 11 dígitos.';
String? passwordRule(String? v) => strongPassword(v ?? '')
    ? null
    : '8 a 32 caracteres, com maiúscula, minúscula, número e símbolo.';

String normalizedName(String value) {
  const accents = 'àáâãäåèéêëìíîïòóôõöùúûüçñ';
  const letters = 'aaaaaaeeeeiiiiooooouuuucn';
  var result = value.toLowerCase();
  for (var i = 0; i < accents.length; i++) {
    result = result.replaceAll(accents[i], letters[i]);
  }
  return result
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String? guardianNameRule(String? v, String patient) =>
    requiredName(v) ??
    (normalizedName(v ?? '') == normalizedName(patient)
        ? 'O nome do responsável deve ser diferente do nome do paciente.'
        : null);
String? guardianCpfRule(String? v, String patient) =>
    requiredCpf(v) ??
    (digits(v ?? '') == digits(patient)
        ? 'O CPF do responsável deve ser diferente do CPF do paciente.'
        : null);
String? guardianPhoneRule(String? v, String patient) =>
    phoneRule(v) ??
    (digits(v ?? '') == digits(patient)
        ? 'O telefone do responsável deve ser diferente do telefone do paciente.'
        : null);
String? guardianEmailRule(String? v, String patient) => emailRule(
            (v ?? '').trim()) !=
        null
    ? 'Informe o e-mail válido do responsável legal.'
    : ((v ?? '').trim().toLowerCase() == patient.trim().toLowerCase()
        ? 'O e-mail do responsável deve ser diferente do e-mail do paciente.'
        : null);
String? guardianBirthRule(String? value) {
  final d = DateTime.tryParse(value ?? '');
  if (d == null) return 'Informe a data de nascimento do responsável.';
  final now = DateTime.now();
  final age = now.year -
      d.year -
      ((now.month < d.month || (now.month == d.month && now.day < d.day))
          ? 1
          : 0);
  return age < 18 ? 'O responsável legal deve ter pelo menos 18 anos.' : null;
}

bool validateAndFocus(GlobalKey<FormState> key) {
  final invalid = key.currentState?.validateGranularly();
  if (invalid == null || invalid.isEmpty) return invalid != null;
  final first = invalid.first;
  Scrollable.ensureVisible(first.context,
      alignment: .3, duration: const Duration(milliseconds: 200));
  void focus(Element element) {
    if (element.widget is EditableText) {
      (element.widget as EditableText).focusNode.requestFocus();
      return;
    }
    element.visitChildren(focus);
  }

  (first.context as Element).visitChildren(focus);
  return false;
}
