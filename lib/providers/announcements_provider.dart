import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_config.dart';
import '../models/announcement.dart';

class AnnouncementsState {
  final List<Announcement> announcements;
  final bool isLoading;

  const AnnouncementsState({this.announcements = const [], this.isLoading = true});

  AnnouncementsState copyWith({List<Announcement>? announcements, bool? isLoading}) {
    return AnnouncementsState(announcements: announcements ?? this.announcements, isLoading: isLoading ?? this.isLoading);
  }

  Announcement? get active {
    for (final a in announcements) {
      if (a.isActive) return a;
    }
    return null;
  }
}

/// Mirrors the announcement slice of src/contexts/SubmissionsContext.tsx —
/// managed by Super Admin in System Settings, shown as a banner on Home.
class AnnouncementsNotifier extends StateNotifier<AnnouncementsState> {
  AnnouncementsNotifier() : super(const AnnouncementsState()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await supabase.from('announcements').select('*').order('created_at', ascending: false);
      state = state.copyWith(announcements: (data as List).map((e) => Announcement.fromMap(e as Map<String, dynamic>)).toList(), isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<({bool success, String? error})> add(String content, bool isActive) async {
    try {
      await supabase.from('announcements').insert({'content': content.trim(), 'is_active': isActive});
      await refresh();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: '$e');
    }
  }

  Future<({bool success, String? error})> update(String id, {String? content, bool? isActive}) async {
    try {
      final updates = <String, dynamic>{};
      if (content != null) updates['content'] = content.trim();
      if (isActive != null) updates['is_active'] = isActive;
      await supabase.from('announcements').update(updates).eq('id', id);
      await refresh();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: '$e');
    }
  }

  Future<({bool success, String? error})> delete(String id) async {
    try {
      await supabase.from('announcements').delete().eq('id', id);
      await refresh();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: '$e');
    }
  }
}

final announcementsProvider = StateNotifierProvider<AnnouncementsNotifier, AnnouncementsState>((ref) => AnnouncementsNotifier());
