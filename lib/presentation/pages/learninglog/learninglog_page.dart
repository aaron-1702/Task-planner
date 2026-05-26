import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection.dart';
import '../../../domain/entities/learning_entry.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/learninglog/learninglog_bloc.dart';

class LearninglogPage extends StatelessWidget {
  const LearninglogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = getIt<LearninglogBloc>();
        final auth = context.read<AuthBloc>().state;
        if (auth is AuthAuthenticated) {
          bloc.add(LearninglogSubscriptionRequested(auth.user.id));
        }
        return bloc;
      },
      child: const _LearninglogView(),
    );
  }
}

class _LearninglogView extends StatelessWidget {
  const _LearninglogView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<LearninglogBloc, LearninglogState>(
      listenWhen: (prev, curr) =>
          prev.error != curr.error || prev.exportCsv != curr.exportCsv,
      listener: (context, state) {
        if (state.error != null && state.error!.isNotEmpty) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.error!)));
        }
        if (state.exportCsv != null) {
          _showExportDialog(context, state.exportCsv!);
          context
              .read<LearninglogBloc>()
              .add(const LearninglogExportDismissed());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Learning Log'),
          actions: [
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export CSV',
              onPressed: () => context
                  .read<LearninglogBloc>()
                  .add(const LearninglogExportRequested()),
            ),
          ],
        ),
        body: const Column(
          children: [
            _ViewModeSelector(),
            _DateNavigator(),
            LearningTimerCard(),
            _SummaryBanner(),
            Expanded(child: _EntryList()),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Add Entry'),
          onPressed: () => _showEntryForm(context),
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context, String csv) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('CSV Export'),
        content: SingleChildScrollView(
          child: SelectableText(
            csv,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ViewModeSelector extends StatelessWidget {
  const _ViewModeSelector();

  @override
  Widget build(BuildContext context) {
    final mode = context.select<LearninglogBloc, LearninglogViewMode>(
      (b) => b.state.viewMode,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SegmentedButton<LearninglogViewMode>(
        segments: const [
          ButtonSegment(
            value: LearninglogViewMode.day,
            label: Text('Day'),
            icon: Icon(Icons.today_outlined),
          ),
          ButtonSegment(
            value: LearninglogViewMode.week,
            label: Text('Week'),
            icon: Icon(Icons.view_week_outlined),
          ),
          ButtonSegment(
            value: LearninglogViewMode.month,
            label: Text('Calendar month'),
            icon: Icon(Icons.calendar_month_outlined),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) => context
            .read<LearninglogBloc>()
            .add(LearninglogViewModeChanged(s.first)),
      ),
    );
  }
}

class _DateNavigator extends StatelessWidget {
  const _DateNavigator();

  @override
  Widget build(BuildContext context) {
    final state =
        context.select<LearninglogBloc, LearninglogState>((b) => b.state);

    void shift(int delta) {
      final d = state.selectedDate;
      DateTime next;
      switch (state.viewMode) {
        case LearninglogViewMode.day:
          next = d.add(Duration(days: delta));
          break;
        case LearninglogViewMode.week:
          next = d.add(Duration(days: delta * 7));
          break;
        case LearninglogViewMode.month:
          next = DateTime(d.year, d.month + delta, 1);
          break;
      }
      context.read<LearninglogBloc>().add(LearninglogDateChanged(next));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => shift(-1),
          ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: state.selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null && context.mounted) {
                context
                    .read<LearninglogBloc>()
                    .add(LearninglogDateChanged(picked));
              }
            },
            child: Text(
              state.periodLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => shift(1),
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Today',
            onPressed: () => context
                .read<LearninglogBloc>()
                .add(LearninglogDateChanged(DateTime.now())),
          ),
        ],
      ),
    );
  }
}

class LearningTimerCard extends StatefulWidget {
  final VoidCallback? onStartOverride;
  final VoidCallback? onStopOverride;
  final bool enableTicker;

  const LearningTimerCard(
      {super.key,
      this.onStartOverride,
      this.onStopOverride,
      this.enableTicker = true});

  @override
  State<LearningTimerCard> createState() => _LearningTimerCardState();
}

class _LearningTimerCardState extends State<LearningTimerCard> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker(DateTime since) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().toUtc().difference(since));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LearninglogBloc, LearninglogState>(
      listenWhen: (prev, curr) => prev.timerRunning != curr.timerRunning,
      listener: (context, state) {
        if (state.timerRunning && state.timerStartedAt != null) {
          if (widget.enableTicker) {
            _startTicker(state.timerStartedAt!);
          } else {
            setState(() => _elapsed =
                DateTime.now().toUtc().difference(state.timerStartedAt!));
          }
        } else {
          _ticker?.cancel();
          setState(() => _elapsed = Duration.zero);
        }
      },
      builder: (context, state) {
        if (!state.timerRunning) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Live timer'),
                subtitle:
                    const Text('Tap Start to begin tracking learning time'),
                trailing: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  onPressed: widget.onStartOverride ??
                      () => context
                          .read<LearninglogBloc>()
                          .add(const LearninglogTimerStarted()),
                ),
              ),
            ),
          );
        }

        final h = _elapsed.inHours.toString().padLeft(2, '0');
        final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
        final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: Icon(Icons.timer,
                  color: Theme.of(context).colorScheme.primary),
              title: Text(
                '$h:$m:$s',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              subtitle: Text(
                'Started at ${DateFormat('HH:mm', 'de_DE').format(state.timerStartedAt!.toLocal())}',
              ),
              trailing: FilledButton.tonalIcon(
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
                onPressed: widget.onStopOverride ?? () => _stopTimer(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _stopTimer(BuildContext context) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    final confirmed = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _StopTimerDialog(),
    );
    if (confirmed == null || !context.mounted) return;

    final breaks = confirmed['break'] as int;
    final topic = confirmed['topic'] as String;
    final note = confirmed['note'] as String?;

    context.read<LearninglogBloc>().add(LearninglogTimerStopped(
          userId: auth.user.id,
          breakMinutes: breaks,
          topic: topic,
          note: note,
        ));
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner();

  @override
  Widget build(BuildContext context) {
    final state =
        context.select<LearninglogBloc, LearninglogState>((b) => b.state);
    final total = state.periodTotalLearning;
    final h = total.inHours;
    final m = total.inMinutes % 60;
    final count = state.periodEntries.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.menu_book_outlined,
            label: '$h h $m min',
            sublabel: 'Net learning time',
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.list_alt_outlined,
            label: '$count',
            sublabel: count == 1 ? 'Entry' : 'Entries',
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;

  const _StatChip(
      {required this.icon, required this.label, required this.sublabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(sublabel, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList();

  @override
  Widget build(BuildContext context) {
    final state =
        context.select<LearninglogBloc, LearninglogState>((b) => b.state);

    if (state.status == LearninglogStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final entries = state.periodEntries;
    final showEntryDate = state.viewMode == LearninglogViewMode.month;

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              'Noch keine Lerneintraege in diesem Zeitraum',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) => LearningEntryTile(
        entry: entries[i],
        showDate: showEntryDate,
      ),
    );
  }
}

class LearningEntryTile extends StatelessWidget {
  final LearningEntry entry;
  final bool showDate;

  const LearningEntryTile({
    required this.entry,
    required this.showDate,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final net = entry.learningDuration;
    final h = net.inHours;
    final m = net.inMinutes % 60;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(
            '${h}h',
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          entry.topic,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDate)
              Text(
                DateFormat('dd.MM.yyyy', 'de_DE').format(entry.date.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Text(
              '${_fmtTime(entry.startTime)} - ${_fmtTime(entry.endTime)}  •  Net: ${h}h ${m}min'
              '${entry.breakMinutes > 0 ? '  •  Pause: ${entry.breakMinutes} min' : ''}',
            ),
            if (entry.note != null && entry.note!.isNotEmpty)
              Text(
                entry.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        isThreeLine: entry.note != null && entry.note!.isNotEmpty,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => _showEntryForm(context, entry: entry),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context, entry),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, LearningEntry entry) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eintrag loeschen?'),
        content:
            const Text('Diese Aktion kann nicht rueckgaengig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      context.read<LearninglogBloc>().add(
            LearninglogEntryDeleted(entryId: entry.id, userId: auth.user.id),
          );
    }
  }

  static String _fmtTime(DateTime d) {
    final local = d.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

void _showEntryForm(BuildContext context, {LearningEntry? entry}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider.value(
      value: context.read<LearninglogBloc>(),
      child: _EntryFormSheet(existing: entry),
    ),
  );
}

class _EntryFormSheet extends StatefulWidget {
  final LearningEntry? existing;

  const _EntryFormSheet({this.existing});

  @override
  State<_EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends State<_EntryFormSheet> {
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late int _breakMinutes;
  final _topicCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _breakCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();

    _date = e?.date ?? now;
    _startTime = e != null
        ? TimeOfDay.fromDateTime(e.startTime.toLocal())
        : TimeOfDay(hour: now.hour, minute: 0);
    _endTime = e != null
        ? TimeOfDay.fromDateTime(e.endTime.toLocal())
        : TimeOfDay(hour: now.hour + 1, minute: 0);
    _breakMinutes = e?.breakMinutes ?? 0;

    _topicCtrl.text = e?.topic ?? '';
    _noteCtrl.text = e?.note ?? '';
    _breakCtrl.text = _breakMinutes.toString();
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    _noteCtrl.dispose();
    _breakCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? 'Lerneintrag bearbeiten' : 'Neuer Lerneintrag',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _topicCtrl,
              decoration: const InputDecoration(
                labelText: 'Topic',
                prefixIcon: Icon(Icons.topic_outlined),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(DateFormat('dd.MM.yyyy', 'de_DE').format(_date)),
              subtitle: const Text('Date'),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.login_outlined),
                    title: Text(_startTime.format(context)),
                    subtitle: const Text('Start'),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (t != null) setState(() => _startTime = t);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout_outlined),
                    title: Text(_endTime.format(context)),
                    subtitle: const Text('End'),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (t != null) setState(() => _endTime = t);
                    },
                  ),
                ),
              ],
            ),
            TextField(
              controller: _breakCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Break (minutes)',
                prefixIcon: Icon(Icons.free_breakfast_outlined),
              ),
              onChanged: (v) => _breakMinutes = int.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submit,
              child: Text(isEdit ? 'Save changes' : 'Add entry'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte ein Topic eingeben.')),
      );
      return;
    }

    final startDt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _startTime.hour,
      _startTime.minute,
    ).toUtc();
    final endDt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _endTime.hour,
      _endTime.minute,
    ).toUtc();

    if (!endDt.isAfter(startDt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Endzeit muss nach Startzeit liegen.')),
      );
      return;
    }

    if (_breakMinutes < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pause darf nicht negativ sein.')),
      );
      return;
    }

    final grossMinutes = endDt.difference(startDt).inMinutes;
    if (_breakMinutes > grossMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pause darf nicht groesser als die Dauer sein.'),
        ),
      );
      return;
    }

    context.read<LearninglogBloc>().add(
          LearninglogEntrySaved(
            existingId: widget.existing?.id,
            userId: auth.user.id,
            date: DateTime(_date.year, _date.month, _date.day),
            startTime: startDt,
            endTime: endDt,
            breakMinutes: _breakMinutes,
            topic: topic,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          ),
        );

    Navigator.of(context).pop();
  }
}

class _StopTimerDialog extends StatefulWidget {
  @override
  State<_StopTimerDialog> createState() => _StopTimerDialogState();
}

class _StopTimerDialogState extends State<_StopTimerDialog> {
  final _breakCtrl = TextEditingController(text: '0');
  final _topicCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _breakCtrl.dispose();
    _topicCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Stop timer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _topicCtrl,
            decoration: const InputDecoration(
              labelText: 'Topic',
              prefixIcon: Icon(Icons.topic_outlined),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _breakCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Break duration (minutes)',
              prefixIcon: Icon(Icons.free_breakfast_outlined),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final topic = _topicCtrl.text.trim();
            if (topic.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bitte ein Topic eingeben.')),
              );
              return;
            }
            Navigator.pop(context, {
              'break': int.tryParse(_breakCtrl.text) ?? 0,
              'topic': topic,
              'note':
                  _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            });
          },
          child: const Text('Save entry'),
        ),
      ],
    );
  }
}
