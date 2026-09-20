import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/data/auth_repository.dart';

class Workspace {
  Workspace({required this.id, required this.name, required this.inviteCode});
  final String id, name, inviteCode;

  factory Workspace.fromMap(Map<String, dynamic> m) => Workspace(
        id: m['id'] as String,
        name: m['name'] as String,
        inviteCode: m['invite_code'] as String,
      );
}

final workspaceRepositoryProvider =
    Provider((ref) => WorkspaceRepository(ref.watch(supabaseProvider)));

/// The user's workspace (null = none yet).
final currentWorkspaceProvider = FutureProvider<Workspace?>((ref) {
  ref.watch(authStateProvider); // refetch on login/logout
  return ref.watch(workspaceRepositoryProvider).current();
});

class WorkspaceRepository {
  WorkspaceRepository(this._c);
  final SupabaseClient _c;

  Future<Workspace?> current() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return null;
    final rows = await _c
        .from('workspace_members')
        .select('workspaces(id, name, invite_code)')
        .eq('user_id', uid)
        .limit(1);
    if (rows.isEmpty) return null;
    return Workspace.fromMap(rows.first['workspaces'] as Map<String, dynamic>);
  }

  Future<void> create(String name) => _c.rpc('create_workspace', params: {'p_name': name});

  Future<void> join(String code) => _c.rpc('join_workspace', params: {'p_code': code});
}

String friendlyWorkspaceError(Object e) {
  final s = e.toString();
  if (s.contains('invalid_code')) return 'كود الدعوة غير صحيح';
  if (s.contains('workspace_full')) return 'هذه المساحة مكتملة (شخصان فقط)';
  return 'تعذر إكمال العملية، تحقق من الاتصال';
}
