import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/task.dart';

final taskRepositoryProvider = Provider((ref) => TaskRepository(ref.watch(supabaseProvider)));

/// Realtime stream of all tasks in a workspace.
final tasksProvider = StreamProvider.family<List<Task>, String>(
  (ref, workspaceId) => ref.watch(taskRepositoryProvider).watch(workspaceId),
);

class TaskRepository {
  TaskRepository(this._c);
  final SupabaseClient _c;

  Stream<List<Task>> watch(String workspaceId) => _c
      .from('tasks')
      .stream(primaryKey: ['id'])
      .eq('workspace_id', workspaceId)
      .order('created_at', ascending: false)
      .map((rows) => rows.map(Task.fromMap).toList());

  Future<void> add({
    required String workspaceId,
    required String title,
    String? description,
    String priority = 'medium',
    String? assignedTo,
    DateTime? dueDate,
  }) =>
      _c.from('tasks').insert({
        'workspace_id': workspaceId,
        'title': title,
        'description': description,
        'priority': priority,
        'assigned_to': assignedTo,
        'due_date': dueDate?.toIso8601String().substring(0, 10),
        'created_by': _c.auth.currentUser!.id,
      });

  Future<void> update(String id, Map<String, dynamic> fields) =>
      _c.from('tasks').update(fields).eq('id', id);

  Future<void> complete(String id) => update(id, {'status': 'completed'});

  Future<void> delete(String id) => _c.from('tasks').delete().eq('id', id);
}
