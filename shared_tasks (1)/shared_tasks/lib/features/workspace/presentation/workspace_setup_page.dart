import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/workspace_repository.dart';
import '../../auth/data/auth_repository.dart';

class WorkspaceSetupPage extends ConsumerStatefulWidget {
  const WorkspaceSetupPage({super.key});
  @override
  ConsumerState<WorkspaceSetupPage> createState() => _State();
}

class _State extends ConsumerState<WorkspaceSetupPage> {
  final _name = TextEditingController(text: 'مهامنا اليومية');
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
      ref.invalidate(currentWorkspaceProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyWorkspaceError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(workspaceRepositoryProvider);
    return Scaffold(
      appBar: AppBar(actions: [
        TextButton(
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          child: const Text('تسجيل الخروج'),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Text('ابدأ مساحتكما المشتركة', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('إنشاء مساحة جديدة'),
              const SizedBox(height: 12),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المساحة')),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : () => _run(() => repo.create(_name.text.trim())),
                child: const Text('إنشاء'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('لديك كود دعوة؟'),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'كود الدعوة (مثال: ABC123)'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _busy ? null : () => _run(() => repo.join(_code.text.trim())),
                child: const Text('انضمام'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
