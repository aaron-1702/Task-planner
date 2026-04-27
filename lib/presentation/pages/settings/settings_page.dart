import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/theme/theme_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user =
            authState is AuthAuthenticated ? authState.user : null;
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
      trailing: const Icon(Icons.chevron_right),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                    color: Theme.of(context).colorScheme.primary,
                  )),
        ),
        BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('Light'),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (v) =>
                      context.read<ThemeCubit>().setTheme(v!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark'),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (v) =>
                      context.read<ThemeCubit>().setTheme(v!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('System default'),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (v) =>
                      context.read<ThemeCubit>().setTheme(v!),
                ),
              ],
            );
          },
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
                    color: Theme.of(context).colorScheme.primary,
                  )),
        ),
        SwitchListTile(
          title: const Text('Deadline Reminders'),
          subtitle: const Text('Get notified before tasks are due'),
          value: true,
          onChanged: (v) {},
        ),
        SwitchListTile(
          title: const Text('Daily Digest'),
          subtitle:
              const Text("Morning summary of today's tasks"),
          value: false,
          onChanged: (v) {},
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
                    color: Theme.of(context).colorScheme.primary,
                  )),
        ),
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: const Text('Export Tasks'),
          subtitle: const Text('Download as CSV or PDF'),
          onTap: () => _showExportDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.sync_outlined),
          title: const Text('Manual Sync'),
          subtitle: const Text('Force synchronization now'),
          onTap: () {},
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
      builder: (_) => AlertDialog(
        title: const Text('Export Tasks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Export as CSV'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Export as PDF'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
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
