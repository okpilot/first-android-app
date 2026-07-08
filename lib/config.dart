/// App configuration, supplied at build/run time via `--dart-define` (see
/// `dev-defines.json` and `backend/README.md`). Never hard-code secrets here.
class AppConfig {
  /// Base URL of the trimmed-Supabase gateway. Defaults to the local dev stack.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Public anon key (a JWT). No safe default — pass it via
  /// `--dart-define-from-file=dev-defines.json`.
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
