import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// Заметка: заголовок + тело + напоминание + повтор + тег + флаги.
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  DateTimeColumn get reminderAt => dateTime().nullable()();
  TextColumn get repeat => text().withDefault(const Constant('none'))(); // none|daily|weekdays|weekly
  TextColumn get tag => text().nullable()(); // 'work' | 'personal' | 'idea' | null
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  BoolColumn get notified => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await customStatement('DROP TABLE IF EXISTS tasks');
            await m.createAll();
          }
          if (from < 3) {
            await m.addColumn(notes, notes.notified);
          }
          if (from < 4) {
            await m.addColumn(notes, notes.repeat);
          }
        },
      );

  Stream<List<Note>> watchNotes() => (select(notes)
        ..orderBy([
          (t) => OrderingTerm(expression: t.pinned, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        ]))
      .watch();

  Future<int> createNote() => into(notes).insert(const NotesCompanion());
  Future<bool> saveNote(Note n) => update(notes).replace(n.copyWith(updatedAt: DateTime.now()));
  Future<int> deleteNote(int id) => (delete(notes)..where((t) => t.id.equals(id))).go();

  Future<void> toggleDone(Note n) => (update(notes)..where((t) => t.id.equals(n.id)))
      .write(NotesCompanion(done: Value(!n.done), updatedAt: Value(DateTime.now())));
  Future<void> togglePinned(Note n) => (update(notes)..where((t) => t.id.equals(n.id)))
      .write(NotesCompanion(pinned: Value(!n.pinned), updatedAt: Value(DateTime.now())));

  // Пометить, что напоминание показано (для разовых — чтобы не повторялось).
  Future<void> markNotified(Note n) => (update(notes)..where((t) => t.id.equals(n.id)))
      .write(NotesCompanion(notified: const Value(true)));

  // Перенести напоминание на дату (для повторов и «отложить»); снова разрешить показ.
  Future<void> reschedule(Note n, DateTime at) => (update(notes)..where((t) => t.id.equals(n.id)))
      .write(NotesCompanion(reminderAt: Value(at), notified: const Value(false)));

  // Отложить на интервал.
  Future<void> snooze(Note n, Duration d) => reschedule(n, DateTime.now().add(d));

  // Восстановить удалённую заметку (для отмены) — с тем же id.
  Future<void> restoreNote(Note n) => into(notes).insertOnConflictUpdate(n);
}

LazyDatabase _open() => LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'notes.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
