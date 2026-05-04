import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/work_entry_model.dart';

const _kTable = 'work_entries';

@injectable
class SupabaseWorkEntryDatasource {
  final SupabaseClient _client;
  const SupabaseWorkEntryDatasource(this._client);

  Future<WorkEntryModel> upsertEntry(WorkEntryModel entry) async {
    final response = await _client
        .from(_kTable)
        .upsert(entry.toJson())
        .select()
        .single();
    return WorkEntryModel.fromJson(response);
  }

  Future<void> deleteEntry(String entryId, String userId) async {
    await _client
        .from(_kTable)
        .delete()
        .eq('id', entryId)
        .eq('user_id', userId);
  }

  Future<List<WorkEntryModel>> getEntriesByUser(String userId) async {
    final response = await _client
        .from(_kTable)
        .select()
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('date', ascending: false);
    return (response as List)
        .map((e) => WorkEntryModel.fromJson(e))
        .toList();
  }

  Future<List<WorkEntryModel>> getEntriesSince(
      String userId, DateTime since) async {
    final response = await _client
        .from(_kTable)
        .select()
        .eq('user_id', userId)
        .gte('updated_at', since.toUtc().toIso8601String())
        .order('updated_at', ascending: false);
    return (response as List)
        .map((e) => WorkEntryModel.fromJson(e))
        .toList();
  }
}
