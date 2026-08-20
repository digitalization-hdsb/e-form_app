import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/feedback.dart';
import 'core/router.dart';
import 'core/supabase_config.dart';
import 'core/theme.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await SupabaseConfig.init();
  }
  runApp(const ProviderScope(child: HdsbEformApp()));
}

class HdsbEformApp extends ConsumerStatefulWidget {
  const HdsbEformApp({super.key});

  @override
  ConsumerState<HdsbEformApp> createState() => _HdsbEformAppState();
}

class _HdsbEformAppState extends ConsumerState<HdsbEformApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // Only matters while following the system setting; forces a rebuild so
    // AppColors' getters re-resolve against the new system brightness.
    if (ref.read(themeModeProvider) == ThemeMode.system) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) {
      AppColors.setDark(false);
      return MaterialApp(theme: buildAppTheme(isDark: false), home: const _MissingConfigScreen());
    }

    final mode = ref.watch(themeModeProvider);
    final systemIsDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    final isDark = mode == ThemeMode.dark || (mode == ThemeMode.system && systemIsDark);
    AppColors.setDark(isDark);

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'HDSB e-Form',
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(isDark: false),
      darkTheme: buildAppTheme(isDark: true),
      themeMode: mode,
      routerConfig: router,
      // Android's edge-to-edge display (mandatory on Android 15+) lets
      // content draw behind the gesture/button navigation bar unless it's
      // explicitly excluded. AppBar already insets for the status bar on
      // its own, so only the bottom inset needs handling here — applied
      // once, globally, instead of adding SafeArea to every screen.
      //
      // The KeyedSubtree is load-bearing, not decorative: AppColors is a
      // plain static getter (hundreds of call sites read it directly,
      // outside Theme/InheritedWidget), so it doesn't push updates to
      // already-built widgets on its own — only whatever happens to rebuild
      // next reads the new colors, which without this made a toggle look
      // like it needed a manual refresh to fully apply. Re-keying on
      // isDark forces every descendant to rebuild immediately instead.
      builder: (context, child) => SafeArea(
        top: false,
        bottom: true,
        child: KeyedSubtree(key: ValueKey('theme-$isDark'), child: child ?? const SizedBox()),
      ),
    );
  }
}

class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Supabase credentials not set',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Run the app with:\n\nflutter run \\\n  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \\\n  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY',
                style: TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Use the same project URL and anon key as the website (see its .env file).',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
