# مهامنا (Shared Tasks) — Flutter + Supabase

## Setup
1. Create a Supabase project and run `schema.sql` in the SQL editor.
2. Auth > Providers: enable Email (Google later).
3. Generate platform folders once, inside this folder:
   flutter create --org com.example --project-name shared_tasks .
4. flutter pub get
5. flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxx

Only the anon key goes in the app. Never put the service_role key here.

## Structure
lib/core (config, theme) - lib/features/<feature>/{domain,data,presentation}
