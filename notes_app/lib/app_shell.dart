import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'providers.dart';

// Управляет треем, окном и глобальным хоткеем.
class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WindowListener, TrayListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initTray();
    _initHotkey();
  }

  Future<void> _initTray() async {
    await trayManager.setIcon('assets/tray_icon.ico');
    await trayManager.setToolTip('Nota');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Открыть Nota'),
      MenuItem(key: 'add', label: 'Добавить заметку'),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: 'Выход'),
    ]));
  }

  // Глобальный хоткей Ctrl+Alt+N: показать окно и создать новую заметку.
  Future<void> _initHotkey() async {
    final hotKey = HotKey(
      key: PhysicalKeyboardKey.keyN,
      modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
      scope: HotKeyScope.system, // работает даже когда окно не в фокусе
    );
    await hotKeyManager.register(hotKey, keyDownHandler: (_) => _quickAdd());
  }

  Future<void> _quickAdd() async {
    await windowManager.show();
    await windowManager.focus();
    final id = await ref.read(dbProvider).createNote();
    ref.read(selectedNoteIdProvider.notifier).select(id);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  // Крестик окна → прячем в трей (процесс продолжает жить).
  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }

  // Левый клик по иконке трея → показать окно.
  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  // Правый клик → контекстное меню.
  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem item) async {
    switch (item.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'add':
        await _quickAdd();
        break;
      case 'exit':
        await windowManager.setPreventClose(false);
        await trayManager.destroy();
        await windowManager.destroy();
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
