import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../workspace/data/workspace_repository.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';

/// First working slice: realtime pending list + add + complete + delete.
/// Completed tab, activity, notifications, settings come in later steps.
class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.workspace});
  final Workspace workspace;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة مهمة'),
        content: TextField(
            controller: title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'عنوان المهمة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة')),
        ],
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      try {
        await ref
            .read(taskRepositoryProvider)
            .add(workspaceId: workspace.id, title: title.text.trim());
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('تعذرت الإضافة')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider(workspace.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(workspace.name),
        actions: [
          IconButton(
            tooltip: 'كود الدعوة',
            icon: const Icon(Icons.person_add_alt),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('كود الدعوة'),
                content: SelectableText(workspace.inviteCode,
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
            ),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('إضافة مهمة'),
      ),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('تعذر تحميل المهام')),
        data: (all) {
          final pending = all.where((t) => !t.completed).toList();
          if (pending.isEmpty) {
            return const Center(child: Text('لا توجد مهام حاليًا 🎉'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: pending.length,
            itemBuilder: (_, i) => _TaskCard(task: pending[i]),
          );
        },
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(taskRepositoryProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(task.title, style: Theme.of(context).textTheme.titleMedium)),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('هل أنت متأكد من حذف هذه المهمة؟'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('حذف')),
                    ],
                  ),
                );
                if (ok == true) await repo.delete(task.id);
              },
            ),
          ]),
          if (task.description != null && task.description!.isNotEmpty) Text(task.description!),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => repo.complete(task.id),
              icon: const Icon(Icons.check),
              label: const Text('تم الإنجاز'),
            ),
          ),
        ]),
      ),
    );
  }
}
