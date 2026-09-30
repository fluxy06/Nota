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

// ---- Выбранная заметка ----
final selectedNoteIdProvider =
    NotifierProvider<SelectedNoteController, int?>(SelectedNoteController.new);
class SelectedNoteController extends Notifier<int?> {
  @override
  int? build() => null;
  void select(int? id) => state = id;
}

// ---- Поиск ----
final searchProvider = NotifierProvider<SearchController, String>(SearchController.new);
class SearchController extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String q) => state = q;
}

// ---- Множественный выбор ----
final selectionModeProvider =
    NotifierProvider<SelectionModeController, bool>(SelectionModeController.new);
class SelectionModeController extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final selectedIdsProvider =
    NotifierProvider<SelectedIdsController, Set<int>>(SelectedIdsController.new);
class SelectedIdsController extends Notifier<Set<int>> {
  @override
  Set<int> build() => {};
  void toggle(int id) {
    final s = {...state};
    if (!s.add(id)) s.remove(id); // add вернул false → уже был → убираем
    state = s;
  }
  void setAll(Iterable<int> ids) => state = {...ids};
  void clear() => state = {};
}

// ---- Отмена/повтор (для удалений) ----
final undoProvider = NotifierProvider<UndoController, int>(UndoController.new);
class UndoController extends Notifier<int> {
  final List<List<Note>> _undo = [];
  final List<List<Note>> _redo = [];
  @override
  int build() => 0; // счётчик-версия, чтобы UI при желании перерисовался

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void recordDelete(List<Note> notes) {
    if (notes.isEmpty) return;
    _undo.add(notes);
    _redo.clear();
    state++;
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    final batch = _undo.removeLast();
    final db = ref.read(dbProvider);
    for (final n in batch) {
      await db.restoreNote(n);
    }
    _redo.add(batch);
    state++;
  }

  Future<void> redo() async {
    if (_redo.isEmpty) return;
    final batch = _redo.removeLast();
    final db = ref.read(dbProvider);
    for (final n in batch) {
      await db.deleteNote(n.id);
    }
    _undo.add(batch);
    state++;
  }
}

// ---- Данные ----
final allNotesProvider = StreamProvider<List<Note>>((ref) => ref.watch(dbProvider).watchNotes());

// Список для среднего столбца: фильтр по разделу + поиск.
final visibleNotesProvider = Provider<List<Note>>((ref) {
  final section = ref.watch(sectionProvider);
  final query = ref.watch(searchProvider).trim().toLowerCase();
  final notes = ref.watch(allNotesProvider).value ?? const [];
  final now = DateTime.now();
  bool isToday(DateTime? d) =>
      d != null && d.year == now.year && d.month == now.month && d.day == now.day;

  Iterable<Note> list;
  switch (section) {
    case Section.all:
      list = notes.where((n) => !n.done);
      break;
    case Section.today:
      list = notes.where((n) => !n.done && isToday(n.reminderAt));
      break;
    case Section.upcoming:
      list = notes.where((n) => !n.done && n.reminderAt != null && n.reminderAt!.isAfter(now));
      break;
    case Section.done:
      list = notes.where((n) => n.done);
      break;
  }
  if (query.isNotEmpty) {
    list = list.where((n) =>
        n.title.toLowerCase().contains(query) || n.body.toLowerCase().contains(query));
  }
  return list.toList();
});
