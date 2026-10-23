part of '../main.dart';

enum ScreenClass { compact, medium, wide }

abstract final class AppBreakpoints {
  static const double compact = 700;
  static const double wide = 1100;
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppSizes {
  static const double minTouchTarget = 48;
  static const double contentMaxWidth = 1320;
}

abstract final class AppRadii {
  static const double control = 12;
  static const double card = 16;
  static const double pill = 999;
}

double responsiveFilterWidth(
  double availableWidth, {
  double minWidth = 220,
  double spacing = 12,
  int maxColumns = 5,
}) {
  final columns = ((availableWidth + spacing) / (minWidth + spacing))
      .floor()
      .clamp(1, maxColumns)
      .toInt();
  return (availableWidth - spacing * (columns - 1)) / columns;
}

ScreenClass screenClassForWidth(double width) {
  if (width < AppBreakpoints.compact) return ScreenClass.compact;
  if (width < AppBreakpoints.wide) return ScreenClass.medium;
  return ScreenClass.wide;
}

ScreenClass screenClassOf(BuildContext context) =>
    screenClassForWidth(MediaQuery.sizeOf(context).width);
