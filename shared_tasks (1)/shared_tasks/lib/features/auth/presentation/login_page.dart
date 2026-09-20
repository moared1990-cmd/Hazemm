import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _signUp = false, _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _msg(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_signUp) {
        await repo.signUp(_name.text.trim(), _email.text.trim(), _pass.text);
      } else {
        await repo.signIn(_email.text.trim(), _pass.text);
      }
    } catch (e) {
      if (mounted) _msg(friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) return _msg('اكتب بريدك أولًا');
    try {
      await ref.read(authRepositoryProvider).resetPassword(_email.text.trim());
      _msg('أرسلنا رابط إعادة التعيين إلى بريدك');
    } catch (e) {
      _msg(friendlyAuthError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('مهامنا', style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(_signUp ? 'إنشاء حساب جديد' : 'تسجيل الدخول'),
                  const SizedBox(height: 24),
                  if (_signUp) ...[
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'الاسم'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                    validator: (v) => (v == null || !v.contains('@')) ? 'بريد غير صالح' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                    validator: (v) => (v == null || v.length < 6) ? '6 أحرف على الأقل' : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_signUp ? 'إنشاء الحساب' : 'دخول'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => ref.read(authRepositoryProvider).signInWithGoogle(),
                      child: const Text('المتابعة عبر Google'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _signUp = !_signUp),
                    child: Text(_signUp ? 'لدي حساب بالفعل' : 'إنشاء حساب جديد'),
                  ),
                  if (!_signUp) TextButton(onPressed: _reset, child: const Text('نسيت كلمة المرور؟')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
