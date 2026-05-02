import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/calendar_event.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/calendar_event/cal_event_bloc.dart';

class EventFormPage extends StatefulWidget {
  final String? eventId;
  final DateTime? initialDate;
  final CalendarEventType? initialType;

  const EventFormPage({
    super.key,
    this.eventId,
    this.initialDate,
    this.initialType,
  });

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  final _formKey = GlobalKey<FormState>();
  CalendarEvent? _existing;

  late CalendarEventType _type;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late DateTime _startDate;
  DateTime? _endDate;
  late EventRecurrence _recurrence;
  int? _reminderMinutes;
  int? _birthYear;

  @override
  void initState() {
    super.initState();
    final state = context.read<CalendarEventBloc>().state;
    _existing = widget.eventId != null
        ? state.events.where((e) => e.id == widget.eventId).firstOrNull
        : null;

    _type = _existing?.type ?? widget.initialType ?? CalendarEventType.event;
    _titleCtrl = TextEditingController(text: _existing?.title ?? '');
    _descCtrl = TextEditingController(text: _existing?.description ?? '');
    _startDate = _existing?.startDate ??
        widget.initialDate ??
        DateTime.now();
    _endDate = _existing?.endDate;
    _recurrence = _existing?.recurrence ??
        (_type == CalendarEventType.birthday
            ? EventRecurrence.yearly
            : EventRecurrence.none);
    _reminderMinutes = _existing?.reminderMinutes;
    _birthYear = _existing?.birthYear ?? _existing?.startDate.year;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = _existing != null;
    final isBirthday = _type == CalendarEventType.birthday;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing
            ? (isBirthday ? 'Edit Birthday' : 'Edit Event')
            : (isBirthday ? 'New Birthday' : 'New Event')),
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Type selector
            _TypeSelector(
              type: _type,
              onChanged: (t) => setState(() {
                _type = t;
                if (t == CalendarEventType.birthday) {
                  _recurrence = EventRecurrence.yearly;
                  _birthYear ??= _startDate.year;
                }
              }),
            ),
            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: isBirthday ? 'Name *' : 'Title *',
                hintText: isBirthday ? 'Whose birthday?' : 'Event title',
                prefixIcon: Icon(
                    isBirthday ? Icons.cake_outlined : Icons.event_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description / Notes',
                hintText: 'Optional…',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),

            // Date & time
            _DateTimeTile(
              label: isBirthday ? 'Birthday Date' : 'Start',
              value: _startDate,
              onChanged: (dt) => setState(() => _startDate = dt),
              showTime: !isBirthday,
            ),
            if (!isBirthday) ...[
              const SizedBox(height: 8),
              _DateTimeTile(
                label: 'End (optional)',
                value: _endDate,
                onChanged: (dt) => setState(() => _endDate = dt),
                showTime: true,
                clearable: true,
                onCleared: () => setState(() => _endDate = null),
              ),
            ],
            const SizedBox(height: 16),

            // Birth year (for age calculation)
            if (isBirthday) ...[
              TextFormField(
                initialValue: _birthYear?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Birth Year (for age)',
                  hintText: 'e.g. 1990',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _birthYear = int.tryParse(v),
              ),
              const SizedBox(height: 16),
            ],

            // Recurrence
            if (!isBirthday) ...[
              _RecurrenceTile(
                value: _recurrence,
                onChanged: (r) => setState(() => _recurrence = r),
              ),
              const SizedBox(height: 16),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.repeat),
                  title: const Text('Recurrence'),
                  subtitle: const Text('Yearly (automatic for birthdays)'),
                  tileColor: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

            // Reminder
            _ReminderTile(
              value: _reminderMinutes,
              onChanged: (v) => setState(() => _reminderMinutes = v),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.user.id
        : 'local-user';

    final now = DateTime.now().toUtc();
    final event = CalendarEvent(
      id: _existing?.id ?? '',
      userId: userId,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      type: _type,
      recurrence: _type == CalendarEventType.birthday
          ? EventRecurrence.yearly
          : _recurrence,
      reminderMinutes: _reminderMinutes,
      birthYear: _type == CalendarEventType.birthday ? _birthYear : null,
      createdAt: _existing?.createdAt ?? now,
      updatedAt: now,
    );

    if (_existing != null) {
      context.read<CalendarEventBloc>().add(CalendarEventUpdated(event));
    } else {
      context.read<CalendarEventBloc>().add(CalendarEventCreated(event));
    }

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/calendar');
    }
  }
}

// ── Type Selector ─────────────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  final CalendarEventType type;
  final ValueChanged<CalendarEventType> onChanged;

  const _TypeSelector({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _TypeChip(
          label: 'Event',
          icon: Icons.event_outlined,
          selected: type == CalendarEventType.event,
          color: cs.primary,
          onTap: () => onChanged(CalendarEventType.event),
        ),
        const SizedBox(width: 12),
        _TypeChip(
          label: 'Birthday',
          icon: Icons.cake_outlined,
          selected: type == CalendarEventType.birthday,
          color: Colors.pink,
          onTap: () => onChanged(CalendarEventType.birthday),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: selected ? color : color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18,
                color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Date/Time Tile ────────────────────────────────────────────────────────────

class _DateTimeTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool showTime;
  final bool clearable;
  final VoidCallback? onCleared;

  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.showTime,
    this.clearable = false,
    this.onCleared,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_month_outlined),
      title: Text(label),
      subtitle: value != null
          ? Text(showTime
              ? DateFormat('EEE, d MMM yyyy – HH:mm').format(value!)
              : DateFormat('EEE, d MMM yyyy').format(value!))
          : const Text('Tap to set'),
      trailing: clearable && value != null
          ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: onCleared,
            )
          : null,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
        );
        if (date == null || !context.mounted) return;
        if (!showTime) {
          onChanged(date);
          return;
        }
        final time = await showTimePicker(
          context: context,
          initialTime:
              TimeOfDay.fromDateTime(value ?? DateTime.now()),
        );
        if (time == null) return;
        onChanged(DateTime(
            date.year, date.month, date.day, time.hour, time.minute));
      },
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// ── Recurrence Tile ───────────────────────────────────────────────────────────

class _RecurrenceTile extends StatelessWidget {
  final EventRecurrence value;
  final ValueChanged<EventRecurrence> onChanged;

  const _RecurrenceTile({required this.value, required this.onChanged});

  static const _labels = {
    EventRecurrence.none: 'No recurrence',
    EventRecurrence.daily: 'Daily',
    EventRecurrence.weekly: 'Weekly',
    EventRecurrence.monthly: 'Monthly',
    EventRecurrence.yearly: 'Yearly',
  };

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<EventRecurrence>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Repeat',
        prefixIcon: Icon(Icons.repeat),
      ),
      items: EventRecurrence.values
          .map((r) => DropdownMenuItem(
                value: r,
                child: Text(_labels[r]!),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ── Reminder Tile ─────────────────────────────────────────────────────────────

class _ReminderTile extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _ReminderTile({required this.value, required this.onChanged});

  static const _options = {
    null: 'No reminder',
    5: '5 minutes before',
    10: '10 minutes before',
    15: '15 minutes before',
    30: '30 minutes before',
    60: '1 hour before',
    1440: '1 day before',
  };

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Reminder',
        prefixIcon: Icon(Icons.notifications_outlined),
      ),
      items: _options.entries
          .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
