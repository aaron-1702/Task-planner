import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injection.dart';
import '../../../services/sync_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/task/task_bloc.dart';
import '../../blocs/theme/theme_cubit.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _deadlineReminders = true;
  bool _dailyDigest = false;
  bool _syncing = false;

  static const _keyDeadline = 'notif_deadline_reminders';
  static const _keyDigest   = 'notif_daily_digest';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deadlineReminders = prefs.getBool(_keyDeadline) ?? true;
      _dailyDigest       = prefs.getBool(_keyDigest)   ?? false;
    });
  }

  Future<void> _setDeadlineReminders(bool value) async {
    if (value && kIsWeb) {
      final permission = await html.Notification.requestPermission();
      if (permission != 'granted') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(
              'Browser notification permission denied. Enable in browser settings.')),
          );
        }
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDeadline, value);
    setState(() => _deadlineReminders = value);
  }

  Future<void> _setDailyDigest(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDigest, value);
    setState(() => _dailyDigest = value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value
          ? 'Daily Digest enabled – you will be reminded each morning.'
          : 'Daily Digest disabled.')),
      );
    }
  }

  void _exportCsv(BuildContext context) {
    final tasks = context.read<TaskBloc>().state.tasks
        .where((t) => !t.isDeleted)
        .toList();

    final buf = StringBuffer();
    buf.writeln('Title,Description,Priority,Status,Deadline,Tags');
    for (final t in tasks) {
      final deadline = t.deadline != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(t.deadline!.toLocal())
          : '';
      final tags = t.tags.join(';');
      buf.writeln(
          '"${_esc(t.title)}","${_esc(t.description ?? '')}","${t.priority.name}","${t.status.name}","$deadline","$tags"');
    }

    if (kIsWeb) {
      final bytes = utf8.encode(buf.toString());
      final blob  = html.Blob([bytes], 'text/csv');
      final url   = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'tasks_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${tasks.length} tasks exported as CSV')));
  }

  Future<void> _exportPdf(BuildContext context) async {
    final tasks = context.read<TaskBloc>().state.tasks
        .where((t) => !t.isDeleted)
        .toList();

    final doc = pw.Document();
    final fmt = DateFormat('yyyy-MM-dd');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context ctx) => [
        pw.Header(
          level: 0,
          child: pw.Text('Smart Task Planner – Tasks',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Exported ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Title', 'Priority', 'Status', 'Deadline'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          data: tasks.map((t) => [
            t.title,
            t.priority.name,
            t.status.name,
            t.deadline != null ? fmt.format(t.deadline!.toLocal()) : '–',
          ]).toList(),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.5),
          },
        ),
      ],
    ));

    final bytes = await doc.save();

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url  = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'tasks_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${tasks.length} tasks exported as PDF')));
    }
  }

  String _esc(String s) => s.replaceAll('"', '""');

  Future<void> _manualSync(BuildContext context) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    setState(() => _syncing = true);
    await getIt<SyncService>().forceSync();
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync completed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              const SliverAppBar(
                title: Text('Settings',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                floating: true,
                snap: true,
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  if (user != null) _buildProfile(context, user),
                  const Divider(),
                  _buildAppearance(context),
                  const Divider(),
                  _buildNotifications(context),
                  const Divider(),
                  _buildDataSection(context),
                  const Divider(),
                  _buildSignOut(context),
                  const SizedBox(height: 40),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfile(BuildContext context, dynamic user) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(user.initials,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary)),
      ),
      title: Text(user.displayName ?? user.email,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(user.email),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }

  Widget _buildAppearance(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text('Appearance',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary)),
        ),
        BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) => Column(children: [
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: themeMode,
              onChanged: (v) => context.read<ThemeCubit>().setTheme(v!),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: themeMode,
              onChanged: (v) => context.read<ThemeCubit>().setTheme(v!),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('System default'),
              value: ThemeMode.system,
              groupValue: themeMode,
              onChanged: (v) => context.read<ThemeCubit>().setTheme(v!),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildNotifications(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text('Notifications',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary)),
        ),
        SwitchListTile(
          title: const Text('Deadline Reminders'),
          subtitle: const Text('Get notified before tasks are due'),
          value: _deadlineReminders,
          onChanged: _setDeadlineReminders,
        ),
        SwitchListTile(
          title: const Text('Daily Digest'),
          subtitle: const Text("Morning summary of today's tasks"),
          value: _dailyDigest,
          onChanged: _setDailyDigest,
        ),
      ],
    );
  }

  Widget _buildDataSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text('Data',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary)),
        ),
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: const Text('Export Tasks'),
          subtitle: const Text('Download as CSV or PDF'),
          onTap: () => _showExportDialog(context),
        ),
        ListTile(
          leading: _syncing
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync_outlined),
          title: const Text('Manual Sync'),
          subtitle: const Text('Force synchronization now'),
          onTap: _syncing ? null : () => _manualSync(context),
        ),
      ],
    );
  }

  Widget _buildSignOut(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: OutlinedButton.icon(
        onPressed: () => _confirmSignOut(context),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
        ),
        icon: const Icon(Icons.logout),
        label: const Text('Sign Out'),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Tasks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Export as CSV'),
              onTap: () => _exportCsv(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Export as PDF'),
              onTap: () => _exportPdf(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(AuthSignOutRequested());
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

