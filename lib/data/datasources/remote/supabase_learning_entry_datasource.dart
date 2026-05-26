import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/learning_entry_model.dart';

const _kTable = 'learning_entries';

@injectable
class SupabaseLearningEntryDatasource {
  final SupabaseClient _client;
  const SupabaseLearningEntryDatasource(this._client);

  Future<LearningEntryModel> upsertEntry(LearningEntryModel entry) async {
    final response =
        await _client.from(_kTable).upsert(entry.toJson()).select().single();
    return LearningEntryModel.fromJson(response);
  }

  Future<void> deleteEntry(String entryId, String userId) async {
    await _client
        .from(_kTable)
        .delete()
        .eq('id', entryId)
        .eq('user_id', userId);
  }

  Future<List<LearningEntryModel>> getEntriesByUser(String userId) async {
    final response = await _client
        .from(_kTable)
        .select()
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('date', ascending: false);
    return (response as List)
        .map((e) => LearningEntryModel.fromJson(e))
        .toList();
  }
}
