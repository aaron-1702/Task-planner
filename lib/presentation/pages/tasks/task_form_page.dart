import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/task.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/task/task_bloc.dart';

class TaskFormPage extends StatefulWidget {
  final String? taskId;
  final DateTime? initialDate;

  const TaskFormPage({super.key, this.taskId, this.initialDate});

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  late final FormGroup _form;
  Task? _existingTask;

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  void _initForm() {
    final state = context.read<TaskBloc>().state;
    _existingTask = widget.taskId != null
        ? state.tasks.where((t) => t.id == widget.taskId).firstOrNull
        : null;

    _form = FormGroup({
      'title': FormControl<String>(
        value: _existingTask?.title ?? '',
        validators: [Validators.required, Validators.minLength(1)],
      ),
      'description': FormControl<String>(
          value: _existingTask?.description ?? ''),
      'deadline': FormControl<DateTime>(
        value: _existingTask?.deadline ?? widget.initialDate,
      ),
      'priority': FormControl<TaskPriority>(
        value: _existingTask?.priority ?? TaskPriority.medium,
      ),
      'status': FormControl<TaskStatus>(
        value: _existingTask?.status ?? TaskStatus.open,
      ),
      'tags': FormControl<String>(
        value: _existingTask?.tags.join(', ') ?? '',
      ),
      'estimatedMinutes': FormControl<int>(
          value: _existingTask?.estimatedMinutes),
      'enableRecurrence': FormControl<bool>(
          value: _existingTask?.recurrenceRule != null),
      'recurrenceType': FormControl<RecurrenceType>(
        value: _existingTask?.recurrenceRule?.type ?? RecurrenceType.daily,
      ),
    });
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existingTask != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task' : 'New Task'),
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ReactiveForm(
        formGroup: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Title
            ReactiveTextField<String>(
              formControlName: 'title',
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'What needs to be done?',
              ),
              validationMessages: {
                ValidationMessage.required: (_) => 'Title is required',
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Description
            ReactiveTextField<String>(
              formControlName: 'description',
              decoration: const InputDecoration(
                labelText: 'Description / Notes',
                hintText: 'Add details…',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),

            // Deadline
            _DeadlinePicker(form: _form),
            const SizedBox(height: 16),

            // Priority & Status row
            Row(
              children: [
                Expanded(child: _PriorityDropdown(form: _form)),
                const SizedBox(width: 12),
                Expanded(child: _StatusDropdown(form: _form)),
              ],
            ),
            const SizedBox(height: 16),

            // Tags
            ReactiveTextField<String>(
              formControlName: 'tags',
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'work, personal, urgent (comma-separated)',
                prefixIcon: Icon(Icons.tag),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),

            // Estimated minutes
            ReactiveTextField<int>(
              formControlName: 'estimatedMinutes',
              decoration: const InputDecoration(
                labelText: 'Estimated Time (minutes)',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 20),

            // Recurrence
            _RecurrenceSection(form: _form),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_form.invalid) {
      _form.markAllAsTouched();
      return;
    }

    final authState = context.read<AuthBloc>().state;
    final String userId;
    if (authState is AuthAuthenticated) {
      userId = authState.user.id;
    } else {
      userId = 'local-user';
    }

    final title = _form.control('title').value as String;
    final description = _form.control('description').value as String?;
    final deadline = _form.control('deadline').value as DateTime?;
    final priority = _form.control('priority').value as TaskPriority;
    final status = _form.control('status').value as TaskStatus;
    final tagsRaw = _form.control('tags').value as String? ?? '';
    final tags = tagsRaw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final estimatedMinutes =
        _form.control('estimatedMinutes').value as int?;
    final enableRecurrence =
        _form.control('enableRecurrence').value as bool? ?? false;
    final recurrenceType =
        _form.control('recurrenceType').value as RecurrenceType;

    RecurrenceRule? rule;
    if (enableRecurrence) {
      rule = RecurrenceRule(type: recurrenceType);
    }

    if (_existingTask != null) {
      context.read<TaskBloc>().add(TaskUpdated(
            _existingTask!.copyWith(
              title: title,
              description: description?.isEmpty == true ? null : description,
              deadline: deadline,
              priority: priority,
              status: status,
              tags: tags,
              recurrenceRule: rule,
              estimatedMinutes: estimatedMinutes,
              updatedAt: DateTime.now().toUtc(),
            ),
          ));
    } else {
      context.read<TaskBloc>().add(TaskCreated(
            userId: userId,
            title: title,
            description: description?.isEmpty == true ? null : description,
            deadline: deadline,
            priority: priority,
            tags: tags,
            recurrenceRule: rule,
            estimatedMinutes: estimatedMinutes,
          ));
    }

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/tasks');
    }
  }
}

class _DeadlinePicker extends StatelessWidget {
  final FormGroup form;
  const _DeadlinePicker({required this.form});

  @override
  Widget build(BuildContext context) {
    return ReactiveFormField<DateTime, DateTime>(
      formControlName: 'deadline',
      builder: (field) {
        final deadline = field.value;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_month_outlined),
          title: const Text('Deadline'),
          subtitle: deadline != null
              ? Text(DateFormat('EEE, MMMM d, yyyy – HH:mm')
                  .format(deadline))
              : const Text('No deadline set'),
          trailing: deadline != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => field.control.value = null,
                )
              : null,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: deadline ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(deadline ?? DateTime.now()),
            );
            if (time == null) return;
            field.control.value = DateTime(
                date.year, date.month, date.day, time.hour, time.minute);
          },
          shape: RoundedRectangleBorder(
            side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }
}

class _PriorityDropdown extends StatelessWidget {
  final FormGroup form;
  const _PriorityDropdown({required this.form});

  @override
  Widget build(BuildContext context) {
    return ReactiveDropdownField<TaskPriority>(
      formControlName: 'priority',
      decoration: const InputDecoration(
        labelText: 'Priority',
        prefixIcon: Icon(Icons.flag_outlined),
      ),
      items: TaskPriority.values
          .map((p) => DropdownMenuItem(
                value: p,
                child: Text(p.name.capitalize()),
              ))
          .toList(),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final FormGroup form;
  const _StatusDropdown({required this.form});

  @override
  Widget build(BuildContext context) {
    return ReactiveDropdownField<TaskStatus>(
      formControlName: 'status',
      decoration: const InputDecoration(
        labelText: 'Status',
        prefixIcon: Icon(Icons.circle_outlined),
      ),
      items: TaskStatus.values
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(s.name.capitalize()),
              ))
          .toList(),
    );
  }
}

class _RecurrenceSection extends StatelessWidget {
  final FormGroup form;
  const _RecurrenceSection({required this.form});

  @override
  Widget build(BuildContext context) {
    return ReactiveFormConsumer(
      builder: (context, form, _) {
        final enabled =
            form.control('enableRecurrence').value as bool? ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recurring Task'),
              subtitle: const Text('Repeat this task automatically'),
              trailing: ReactiveSwitch.adaptive(
                formControlName: 'enableRecurrence',
              ),
            ),
            if (enabled) ...[
              const SizedBox(height: 12),
              ReactiveDropdownField<RecurrenceType>(
                formControlName: 'recurrenceType',
                decoration: const InputDecoration(
                  labelText: 'Repeat',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: [
                  RecurrenceType.daily,
                  RecurrenceType.weekly,
                  RecurrenceType.monthly,
                ]
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.name.capitalize()),
                        ))
                    .toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}

extension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
