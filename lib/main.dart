import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'data/contacts_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // Our dev key is a legacy anon JWT, not a new `sb_publishable_*` key, so the
    // anonKey path is the correct one here.
    // ignore: deprecated_member_use
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(
    ContactsApp(
      repository: SupabaseContactsRepository(Supabase.instance.client),
    ),
  );
}
