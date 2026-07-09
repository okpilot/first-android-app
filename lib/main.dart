import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'data/contacts_repository.dart';
import 'data/events_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // Our dev key is a legacy anon JWT, not a new `sb_publishable_*` key, so the
      // anonKey path is the correct one here.
      // ignore: deprecated_member_use
      anonKey: AppConfig.supabaseAnonKey,
    );
    final client = Supabase.instance.client;
    runApp(
      ContactsApp(
        repository: SupabaseContactsRepository(client),
        eventsRepository: SupabaseEventsRepository(client),
      ),
    );
  } catch (error) {
    // Backend init failed (bad config / unreachable). Show a screen instead of
    // crashing before any UI exists.
    runApp(_StartupErrorApp(error: error));
  }
}

/// Minimal fallback UI when the app can't initialize its backend at startup.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 16),
                const Text(
                  "Couldn't start the app",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
