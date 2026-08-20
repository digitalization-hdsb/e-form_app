import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette lifted from the website's src/index.css HSL tokens for
/// BOTH `:root` (light) and `.dark`. Fields are getters (not `static const`)
/// so every call site — hundreds of `AppColors.xxx` references across the
/// app — automatically reflects the active theme without needing a
/// BuildContext threaded through every widget. [setDark] is called once per
/// frame from the app root before the tree rebuilds, so all getters read
/// consistently within that build pass.
class AppColors {
  AppColors._();

  static bool _isDark = false;
  static void setDark(bool value) => _isDark = value;
  static bool get isDark => _isDark;

  // Brand navy — the primary color in light mode. Dark mode swaps the
  // *primary* role to gold (matching the website's `.dark { --primary }`),
  // so use [primary] for anything that should follow that swap, and
  // [navy] for chrome that should always stay navy regardless of mode
  // (e.g. the login screen background, the sidebar).
  static const navy = Color(0xFF1F2A5C);
  static const navyDark = Color(0xFF141B42);
  static const gold = Color(0xFFF6B93B);

  static Color get primary => _isDark ? gold : navy;
  static Color get primaryDark => navyDark; // text-on-gold, both modes
  static Color get onPrimary => _isDark ? navyDark : Colors.white;

  /// A gold/amber accent for text and icons on top of a card (not a solid
  /// gold background) — [gold] itself is a pale tint that reads fine against
  /// dark chrome but washes out against a white card, so light mode uses a
  /// deeper amber here instead (matching the website's `--accent` token,
  /// which is likewise darkened rather than reusing its raw gold).
  static Color get accent => _isDark ? gold : const Color(0xFFD4900A);

  static Color get background => _isDark ? const Color(0xFF0B0E20) : const Color(0xFFF5F6FA);
  static Color get card => _isDark ? const Color(0xFF12162E) : Colors.white;
  static Color get foreground => _isDark ? const Color(0xFFEDEFF3) : const Color(0xFF1D2233);
  static Color get mutedForeground => _isDark ? const Color(0xFF98A0C6) : const Color(0xFF6E7280);
  static Color get border => _isDark ? const Color(0xFF262B52) : const Color(0xFFE3E5EC);
  static Color get destructive => _isDark ? const Color(0xFFF87171) : const Color(0xFFD32F2F);
  static Color get success => _isDark ? const Color(0xFF34D399) : const Color(0xFF22B36B);
  static Color get warning => gold;

  /// A single, deliberately vivid green for "your action succeeded" toasts
  /// (form submitted, record saved, etc). Kept constant across light/dark —
  /// unlike [success] it's a full-bleed SnackBar background, not text/icon
  /// tint on a surface, so it doesn't need to adapt to the theme.
  static const successBright = Color(0xFF00C853);

  /// Per-department brand colors, matching the website's Home page cards
  /// (Tailwind blue-500/red-500/violet-500) — used for that department's
  /// icon boxes both on Home and inside its own form-selection screen, so
  /// the color stays consistent as you drill in, instead of every form
  /// list defaulting to the same navy/gold primary.
  static const deptHr = Color(0xFF3B82F6);
  static const deptFinance = gold;
  static const deptSafety = Color(0xFFEF4444);
  static const deptIt = Color(0xFF8B5CF6);

  /// Matches the website's `.card-elevated` box-shadow (two soft layers).
  /// Skipped in dark mode — a black shadow is invisible against a near-black
  /// background, so the card's [border] alone carries the separation there.
  static List<BoxShadow> get cardShadow => _isDark
      ? const []
      : [
          BoxShadow(color: navy.withValues(alpha: 0.08), blurRadius: 3, offset: const Offset(0, 1)),
          BoxShadow(color: navy.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ];
}

ThemeData buildAppTheme({required bool isDark}) {
  final scheme = isDark
      ? ColorScheme.fromSeed(
          seedColor: AppColors.gold,
          brightness: Brightness.dark,
          primary: AppColors.gold,
          onPrimary: AppColors.navyDark,
          secondary: AppColors.gold,
          error: AppColors.destructive,
          surface: AppColors.card,
        )
      : ColorScheme.fromSeed(
          seedColor: AppColors.navy,
          brightness: Brightness.light,
          primary: AppColors.navy,
          secondary: AppColors.gold,
          error: AppColors.destructive,
          surface: AppColors.card,
        );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: scheme.brightness);
  final headingFont = GoogleFonts.poppinsTextTheme(base.textTheme);
  final bodyFont = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    displayLarge: headingFont.displayLarge,
    displayMedium: headingFont.displayMedium,
    displaySmall: headingFont.displaySmall,
    headlineLarge: headingFont.headlineLarge,
    headlineMedium: headingFont.headlineMedium,
    headlineSmall: headingFont.headlineSmall,
    titleLarge: headingFont.titleLarge,
    titleMedium: headingFont.titleMedium,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: bodyFont.apply(bodyColor: AppColors.foreground, displayColor: AppColors.foreground),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyDark,
        minimumSize: const Size(64, 54),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
        elevation: 2,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.foreground,
        side: BorderSide(color: AppColors.border, width: 2),
        minimumSize: const Size(64, 54),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.primary)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: AppColors.mutedForeground),
      hintStyle: TextStyle(color: AppColors.mutedForeground),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border)),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(backgroundColor: AppColors.card, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: AppColors.card, surfaceTintColor: Colors.transparent),
    popupMenuTheme: PopupMenuThemeData(color: AppColors.card, surfaceTintColor: Colors.transparent),
    dividerTheme: DividerThemeData(color: AppColors.border),
    iconTheme: IconThemeData(color: AppColors.foreground),
    listTileTheme: ListTileThemeData(iconColor: AppColors.foreground, textColor: AppColors.foreground),
    checkboxTheme: CheckboxThemeData(fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.primary : null)),
    switchTheme: SwitchThemeData(thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.gold : null)),
    chipTheme: base.chipTheme.copyWith(backgroundColor: AppColors.card, side: BorderSide(color: AppColors.border)),
    snackBarTheme: SnackBarThemeData(backgroundColor: AppColors.foreground, contentTextStyle: TextStyle(color: AppColors.background)),
  );
}
