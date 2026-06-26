import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://twqjejtpqybegyidwwaz.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR3cWplanRwcXliZWd5aWR3d2F6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5ODI3MjUsImV4cCI6MjA5NjU1ODcyNX0.laDaP72O65aQagyxafgn1KDAL1cZaGsbbc5Cl1ZNi3s';

  /// Returns the initialized Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;
}
