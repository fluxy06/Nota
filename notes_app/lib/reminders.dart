import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';
import 'data/database.dart';
import 'providers.dart';

// Какое напоминание сейчас показывается в карточке (null — ничего).
final firingReminderProvider =
    NotifierProvider<FiringReminder, Note?>(FiringReminder.new);
class FiringReminder extends Notifier<Note?> {
  @override
  Note? build() => null;
  void show(Note n) => state = n;
  void dismiss() => state = null;
}

// Следующая дата повтора после текущего reminderAt, строго в будущем. null — если разовое.
DateTime? nextOccurrence(Note n) {
  if (n.reminderAt == null || n.repeat == 'none') return null;
  final now = DateTime.now();
  DateTime advance(DateTime d) {
    switch (n.repeat) {
      case 'weekly':
        return d.add(const Duration(days: 7));
      case 'weekdays':
        var x = d.add(const Duration(days: 1));
        while (x.weekday == DateTime.saturday || x.weekday == DateTime.sunday) {
          x = x.add(const Duration(days: 1));
        }
        return x;
      case 'daily':
      default:
        return d.add(const Duration(days: 1));
    }
  }
  var t = n.reminderAt!;
  do {
    t = advance(t);
  } while (!t.isAfter(now)); // проматываем пропущенные — до ближайшего будущего
  return t;
}

// Фоновый «движок»: раз в 12 сек проверяет, не пора ли напомнить.
class ReminderHost extends ConsumerStatefulWidget {
  final Widget child;
  const ReminderHost({super.key, required this.child});
  @override
  ConsumerState<ReminderHost> createState() => _ReminderHostState();
}

class _ReminderHostState extends ConsumerState<ReminderHost> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (!mounted) return;
    if (ref.read(firingReminderProvider) != null) return; // карточка уже показана — ждём
    final notes = ref.read(allNotesProvider).value ?? const [];
    final now = DateTime.now();
    Note? due;
    for (final n in notes) {
      if (!n.done && !n.notified && n.reminderAt != null && !n.reminderAt!.isAfter(now)) {
        if (due == null || n.reminderAt!.isBefore(due.reminderAt!)) due = n;
      }
    }
    if (due != null) {
      final note = due;
      ref.read(firingReminderProvider.notifier).show(note); // внутренняя карточка
      _showOsNotification(note);                            // системное уведомление ОС

      final next = nextOccurrence(note);
      if (next != null) {
        await ref.read(dbProvider).reschedule(note, next); // повтор → перенос на след. дату
      } else {
        await ref.read(dbProvider).markNotified(note);     // разовое → погасить
      }
    }
  }

  // Настоящее уведомление уровня ОС. Клик выводит окно на передний план.
  void _showOsNotification(Note note) {
    final notif = LocalNotification(
      title: 'Nota — напоминание',
      body: note.title.isEmpty ? 'Без названия' : note.title,
    );
    notif.onClick = () async {
      await windowManager.show();
      await windowManager.focus();
      ref.read(selectedNoteIdProvider.notifier).select(note.id);
    };
    notif.show();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// Оверлей: красивая карточка поверх окна приложения (низ-право).
class ReminderOverlay extends ConsumerWidget {
  final Widget child;
  const ReminderOverlay({super.key, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(firingReminderProvider);
    return Stack(children: [
      child,
      if (note != null)
        Positioned(right: 24, bottom: 24, child: _ReminderCard(note: note)),
    ]);
  }
}

class _ReminderCard extends ConsumerWidget {
  final Note note;
  const _ReminderCard({required this.note});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final db = ref.read(dbProvider);
    void dismiss() => ref.read(firingReminderProvider.notifier).dismiss();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(.4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: cs.primary.withOpacity(.15), shape: BoxShape.circle),
              child: Icon(Icons.notifications_active_rounded, size: 19, color: cs.primary),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1, end: 1.12, duration: 700.ms, curve: Curves.easeInOut),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Напоминание', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary)),
              if (note.reminderAt != null)
                Text(DateFormat('dd.MM HH:mm').format(note.reminderAt!),
                    style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
            ])),
            IconButton(onPressed: dismiss, icon: const Icon(Icons.close, size: 18), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 8),
          Text(note.title.isEmpty ? 'Без названия' : note.title,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
          if (note.body.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(note.body, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            FilledButton(
              onPressed: () { db.toggleDone(note); dismiss(); },
              child: const Text('Выполнено'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () { db.snooze(note, const Duration(minutes: 10)); dismiss(); },
              child: const Text('Отложить 10 мин'),
            ),
          ]),
        ]),
      ),
    ).animate().fadeIn(duration: 260.ms).slideX(begin: .3, end: 0, curve: Curves.easeOutCubic);
  }
}
