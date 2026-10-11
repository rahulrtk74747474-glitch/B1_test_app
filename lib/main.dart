import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  await AppDatabase.instance.seedSampleIfEmpty();
  final prefs = await SharedPreferences.getInstance();
  runApp(B1App(prefs: prefs));
}

class B1App extends StatefulWidget {
  const B1App({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  State<B1App> createState() => _B1AppState();
}

class _B1AppState extends State<B1App> {
  late ThemeMode themeMode;
  late Future<void> bankReady;

  @override
  void initState() {
    super.initState();
    bankReady = AppDatabase.instance.seedBundledQuestions();
    themeMode = switch (widget.prefs.getString('theme_mode')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setTheme(ThemeMode mode) async {
    setState(() => themeMode = mode);
    await widget.prefs.setString('theme_mode', mode.name);
  }

  ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0C447D),
      brightness: brightness,
      surface: dark ? const Color(0xFF111318) : const Color(0xFFF8F9FC),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamilyFallback: const ['Noto Sans Devanagari', 'sans-serif'],
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 28, height: 1.2),
        titleLarge: TextStyle(fontSize: 20, height: 1.3),
        titleMedium: TextStyle(fontSize: 17, height: 1.35),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45),
        bodyMedium: TextStyle(fontSize: 15, height: 1.45),
        bodySmall: TextStyle(fontSize: 13, height: 1.35),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurface),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 10,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Police B1 Test',
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        themeMode: themeMode,
        home: FutureBuilder<void>(
          future: bankReady,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Scaffold(body: SafeArea(child: Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text('The question bank could not finish loading.'),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton(onPressed: () => setState(() {
                    bankReady = AppDatabase.instance.seedBundledQuestions();
                  }), child: const Text('Retry loading')),
                ]),
              ))));
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: SafeArea(child: Center(
                child: Padding(padding: EdgeInsets.all(24), child:
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.shield_outlined, size: 64),
                    SizedBox(height: 20),
                    Text('Police B1 Test', style: TextStyle(fontSize: 24,
                      fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text('Preparing your offline question bank…',
                      textAlign: TextAlign.center),
                    SizedBox(height: 18),
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('This happens on the first launch only.',
                      textAlign: TextAlign.center),
                  ]),
                ),
              )));
            }
            return AppShell(
              prefs: widget.prefs,
              themeMode: themeMode,
              onThemeChanged: setTheme,
            );
          },
        ),
      );
}
