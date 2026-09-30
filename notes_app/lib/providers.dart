import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/database.dart';

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ---- Тема ----
final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';
  @override
  ThemeMode build() { _load(); return ThemeMode.light; }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key) == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }
  Future<void> toggle() async {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, state == ThemeMode.dark ? 'dark' : 'light');
  }
}

// ---- Разделы слева ----
enum Section { all, today, upcoming, done }

final sectionProvider = NotifierProvider<SectionController, Section>(SectionController.new);
class SectionController extends Notifier<Section> {
  @override
  Section build() => Section.all;
  void select(Section s) => state = s;
}

// ---- Какая заметка выбрана ----
final selectedNoteIdProvider =
    NotifierProvider<SelectedNoteController, int?>(SelectedNoteController.new);
class SelectedNoteController extends Notifier<int?> {
  @override
  int? build() => null;
  void select(int? id) => state = id;
}

// ---- Данные ----
final allNotesProvider = StreamProvider<List<Note>>((ref) => ref.watch(dbProvider).watchNotes());

// Отфильтрованный по разделу список для среднего столбца.
final visibleNotesProvider = Provider<List<Note>>((ref) {
  final section = ref.watch(sectionProvider);
  final notes = ref.watch(allNotesProvider).value ?? const [];
  final now = DateTime.now();
  bool isToday(DateTime? d) =>
      d != null && d.year == now.year && d.month == now.month && d.day == now.day;
  switch (section) {
    case Section.all:      return notes.where((n) => !n.done).toList();
    case Section.today:    return notes.where((n) => !n.done && isToday(n.reminderAt)).toList();
    case Section.upcoming: return notes.where((n) => !n.done && n.reminderAt != null && n.reminderAt!.isAfter(now)).toList();
    case Section.done:     return notes.where((n) => n.done).toList();
  }
});