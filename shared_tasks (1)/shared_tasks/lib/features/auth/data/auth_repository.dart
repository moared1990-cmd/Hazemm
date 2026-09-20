import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseProvider)));

/// Emits the current session (null = signed out).
final authStateProvider = StreamProvider<Session?>((ref) async* {
  final client = ref.watch(supabaseProvider);
  yield client.auth.currentSession;
  yield* client.auth.onAuthStateChange.map((e) => e.session);
});

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  Future<void> signUp(String name, String email, String password) =>
      _client.auth.signUp(email: email, password: password, data: {'name': name});

  Future<void> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signInWithGoogle() => _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.sharedtasks://login-callback/',
      );

  Future<void> resetPassword(String email) => _client.auth.resetPasswordForEmail(email);

  Future<void> signOut() => _client.auth.signOut();
}

String friendlyAuthError(Object e) {
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'البريد أو كلمة المرور غير صحيحة';
    if (m.contains('already registered')) return 'هذا البريد مسجل مسبقًا';
    if (m.contains('password')) return 'كلمة المرور ضعيفة (6 أحرف على الأقل)';
    return e.message;
  }
  return 'تحقق من اتصال الإنترنت وحاول مرة أخرى';
}
