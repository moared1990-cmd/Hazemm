import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/workspace/data/workspace_repository.dart';
import 'features/workspace/presentation/workspace_setup_page.dart';
import 'features/tasks/presentation/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Config.supabaseUrl,
    anonKey: Config.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'مهامنا',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'), // RTL
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      );
}

/// Login -> workspace setup -> home
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('حدث خطأ: $e'))),
      data: (session) {
        if (session == null) return const LoginPage();
        final ws = ref.watch(currentWorkspaceProvider);
        return ws.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('تعذر التحميل: $e'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(currentWorkspaceProvider),
                  child: const Text('إعادة المحاولة'),
                ),
              ]),
            ),
          ),
          data: (w) => w == null ? const WorkspaceSetupPage() : HomePage(workspace: w),
        );
      },
    );
  }
}
