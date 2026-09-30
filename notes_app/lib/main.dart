import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'theme.dart';
import 'providers.dart';
import 'reminders.dart';
import 'app_shell.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Окно приложения
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1120, 720),
    minimumSize: Size(880, 560),
    center: true,
    title: 'Nota',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  await windowManager.setPreventClose(true); // крестик = свернуть в трей

  // Системные уведомления ОС
  await localNotifier.setup(
    appName: 'Nota',
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );

  // Автозапуск при входе в систему
  launchAtStartup.setup(
    appName: 'Nota',
    appPath: Platform.resolvedExecutable,
  );
  await launchAtStartup.enable();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Nota',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      themeAnimationDuration: const Duration(milliseconds: 300),
      themeAnimationCurve: Curves.easeOutCubic,
      // AppShell (трей/окно) → ReminderHost (движок) → ReminderOverlay (карточка) → экран.
      home: const AppShell(
        child: ReminderHost(child: ReminderOverlay(child: HomeScreen())),
      ),
    );
  }
}
