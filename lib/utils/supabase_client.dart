import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://rrulszmznapwusycqzob.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJydWxzem16bmFwd3VzeWNxem9iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA3MzgzNDIsImV4cCI6MjA2NjMxNDM0Mn0.C04B-_g7jucPrSMcDHNw3cPAZ4Gxj9B5CLrJa5c6vB0';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
} 