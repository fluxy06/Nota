import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';
import '../providers.dart';

const _tagColors = {'work': Color(0xFF007AFF), 'personal': Color(0xFF34C759), 'idea': Color(0xFFFF9F0A)};
const _tagNames = {'work': 'Работа', 'personal': 'Личное', 'idea': 'Идеи'};
String _fmt(DateTime d) => DateFormat('dd.MM HH:mm').format(d);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Row(children: [
        SizedBox(width: 236, child: _Sidebar()),
        VerticalDivider(width: 1),
        SizedBox(width: 340, child: _NoteList()),
        VerticalDivider(width: 1),
        Expanded(child: _DetailPane()),
      ]),
    );
  }
}

// ---------------- Sidebar ----------------
class _Sidebar extends ConsumerWidget {
  const _Sidebar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final section = ref.watch(sectionProvider);
    final notes = ref.watch(allNotesProvider).value ?? const [];
    final active = notes.where((n) => !n.done).length;
    final doneN = notes.where((n) => n.done).length;
    final percent = notes.isEmpty ? 0.0 : doneN / notes.length;

    Widget nav(Section s, IconData icon, String label, [int? count]) {
      final sel = section == s;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: sel ? cs.primary.withOpacity(.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => ref.read(sectionProvider.notifier).select(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(children: [
                Icon(icon, size: 19, color: sel ? cs.primary : cs.onSurfaceVariant),
                const SizedBox(width: 11),
                Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: sel ? cs.primary : cs.onSurface)),
                const Spacer(),
                if (count != null && count > 0)
                  Text('$count', style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      color: cs.surfaceContainerLow,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 10, 10),
          child: Row(children: [
            Text('Nota', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface)),
            const Spacer(),
            const _ThemeToggle(),
          ]),
        ),
        nav(Section.today, Icons.today_rounded, 'Сегодня'),
        nav(Section.upcoming, Icons.schedule_rounded, 'Предстоящие'),
        nav(Section.all, Icons.notes_rounded, 'Все заметки', active),
        nav(Section.done, Icons.check_circle_outline_rounded, 'Выполненные', doneN),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            SizedBox(width: 44, height: 44, child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 44, height: 44, child: CircularProgressIndicator(
                value: percent, strokeWidth: 4,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(cs.primary))),
              Text('${(percent * 100).round()}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cs.primary)),
            ])),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Статистика', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
              Text('${notes.length} заметок', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ---------------- Middle list ----------------
class _NoteList extends ConsumerWidget {
  const _NoteList();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final notes = ref.watch(visibleNotesProvider);
    final selId = ref.watch(selectedNoteIdProvider);
    return Container(
      color: cs.surface,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
          child: Row(children: [
            Expanded(child: Container(
              height: 36, padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(9)),
              child: Row(children: [
                Icon(Icons.search, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Поиск…', style: TextStyle(color: cs.onSurfaceVariant)),
              ]),
            )),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Новая заметка',
              onPressed: () async {
                final id = await ref.read(dbProvider).createNote();
                ref.read(selectedNoteIdProvider.notifier).select(id);
              },
              icon: const Icon(Icons.add),
            ),
          ]),
        ),
        Expanded(
          child: notes.isEmpty
              ? Center(child: Text('Нет заметок', style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: notes.length,
                  itemBuilder: (_, i) {
                    final n = notes[i];
                    return _NoteCard(note: n, selected: n.id == selId)
                        .animate().fadeIn(duration: 200.ms).slideY(begin: .08, end: 0, curve: Curves.easeOut);
                  },
                ),
        ),
      ]),
    );
  }
}

class _NoteCard extends ConsumerWidget {
  final Note note;
  final bool selected;
  const _NoteCard({required this.note, required this.selected});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tagColor = note.tag == null ? null : _tagColors[note.tag];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? cs.primary.withOpacity(.12) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => ref.read(selectedNoteIdProvider.notifier).select(note.id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (tagColor != null) ...[
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(
                  note.title.isEmpty ? 'Без названия' : note.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: note.title.isEmpty ? cs.onSurfaceVariant : cs.onSurface,
                    decoration: note.done ? TextDecoration.lineThrough : null),
                )),
              ]),
              if (note.body.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(note.body, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ],
              if (note.reminderAt != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.notifications_none_rounded, size: 14, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(_fmt(note.reminderAt!),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------- Detail / editor ----------------
class _DetailPane extends ConsumerWidget {
  const _DetailPane();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final selId = ref.watch(selectedNoteIdProvider);
    final notes = ref.watch(allNotesProvider).value ?? const [];
    Note? note;
    for (final n in notes) {
      if (n.id == selId) { note = n; break; }
    }
    if (note == null) {
      return Container(
        color: cs.surface,
        alignment: Alignment.center,
        child: Text('Выбери заметку или создай новую', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return _NoteEditor(key: ValueKey(note.id), note: note);
  }
}

class _NoteEditor extends ConsumerStatefulWidget {
  final Note note;
  const _NoteEditor({super.key, required this.note});
  @override
  ConsumerState<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<_NoteEditor> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late Note _n;

  @override
  void initState() {
    super.initState();
    _n = widget.note;
    _title = TextEditingController(text: _n.title);
    _body = TextEditingController(text: _n.body);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _saveText() {
    _n = _n.copyWith(title: _title.text, body: _body.text);
    ref.read(dbProvider).saveNote(_n);
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context, firstDate: DateTime(2020), lastDate: DateTime(2100),
        initialDate: _n.reminderAt ?? now);
    if (d == null) return;
    final tm = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_n.reminderAt ?? now));
    final dt = DateTime(d.year, d.month, d.day, tm?.hour ?? 9, tm?.minute ?? 0);
    setState(() => _n = _n.copyWith(reminderAt: Value(dt)));
    ref.read(dbProvider).saveNote(_n);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(36, 20, 36, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Spacer(),
          IconButton(
            tooltip: 'Закрепить',
            onPressed: () async {
              await ref.read(dbProvider).togglePinned(_n);
              setState(() => _n = _n.copyWith(pinned: !_n.pinned));
            },
            icon: Icon(_n.pinned ? Icons.push_pin : Icons.push_pin_outlined),
          ),
          IconButton(
            tooltip: 'Выполнено',
            onPressed: () async {
              await ref.read(dbProvider).toggleDone(_n);
              setState(() => _n = _n.copyWith(done: !_n.done));
            },
            icon: Icon(_n.done ? Icons.check_circle : Icons.radio_button_unchecked),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: () async {
              await ref.read(dbProvider).deleteNote(_n.id);
              ref.read(selectedNoteIdProvider.notifier).select(null);
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ]),
        TextField(
          controller: _title,
          onChanged: (_) => _saveText(),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          decoration: const InputDecoration(border: InputBorder.none, hintText: 'Заголовок'),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ActionChip(
            avatar: Icon(Icons.notifications_none_rounded, size: 18, color: cs.primary),
            label: Text(_n.reminderAt == null ? 'Напоминание' : _fmt(_n.reminderAt!)),
            onPressed: _pickReminder,
          ),
          if (_n.reminderAt != null)
            IconButton(
              tooltip: 'Убрать напоминание',
              onPressed: () {
                setState(() => _n = _n.copyWith(reminderAt: const Value(null)));
                ref.read(dbProvider).saveNote(_n);
              },
              icon: const Icon(Icons.close, size: 18),
            ),
          for (final e in _tagNames.entries)
            FilterChip(
              selected: _n.tag == e.key,
              label: Text(e.value),
              avatar: Container(width: 10, height: 10, decoration: BoxDecoration(color: _tagColors[e.key], shape: BoxShape.circle)),
              onSelected: (sel) {
                setState(() => _n = _n.copyWith(tag: Value(sel ? e.key : null)));
                ref.read(dbProvider).saveNote(_n);
              },
            ),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: TextField(
            controller: _body,
            onChanged: (_) => _saveText(),
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontSize: 15.5, height: 1.6),
            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Текст заметки…'),
          ),
        ),
      ]),
    );
  }
}

// Переключатель темы (солнце↔луна).
class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return IconButton(
      tooltip: 'Сменить тему',
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: Tween(begin: 0.7, end: 1.0).animate(anim),
          child: FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
        ),
        child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, key: ValueKey(isDark)),
      ),
    );
  }
}