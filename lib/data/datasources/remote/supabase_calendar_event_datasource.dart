import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/calendar_event.dart';
import '../../models/calendar_event_model.dart';

@singleton
class SupabaseCalendarEventDatasource {
  final SupabaseClient _client;
  SupabaseCalendarEventDatasource(this._client);

  Future<List<CalendarEventModel>> getEventsByUser(String userId) async {
    final response = await _client
        .from('calendar_events')
        .select()
        .eq('user_id', userId)
        .eq('is_deleted', false);
    return (response as List)
        .map((e) => CalendarEventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CalendarEventModel> createEvent(CalendarEventModel event) async {
    final response = await _client
        .from('calendar_events')
        .insert(event.toJson())
        .select()
        .single();
    return CalendarEventModel.fromJson(response);
  }

  Future<CalendarEventModel> updateEvent(CalendarEventModel event) async {
    final response = await _client
        .from('calendar_events')
        .update(event.toJson())
        .eq('id', event.id)
        .select()
        .single();
    return CalendarEventModel.fromJson(response);
  }

  Future<void> deleteEvent(String eventId, String userId) async {
    await _client
        .from('calendar_events')
        .delete()
        .eq('id', eventId)
        .eq('user_id', userId);
  }

  Future<List<CalendarEventModel>> getEventsSince(
      String userId, DateTime since) async {
    final response = await _client
        .from('calendar_events')
        .select()
        .eq('user_id', userId)
        .gte('updated_at', since.toUtc().toIso8601String());
    return (response as List)
        .map((e) => CalendarEventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
