import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'controllers/auth_controller.dart';
import 'controllers/feed_controller.dart';
import 'controllers/pet_controller.dart';
import 'controllers/language_controller.dart';
import 'services/supabase_service.dart';
import 'services/r2_storage_service.dart';
import 'services/render_backend_service.dart';
import 'services/dynamic_auth_service.dart';
import 'theme/app_theme.dart';
import 'views/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization fallback: $e');
  }

  // Shared Core Services
  final supabaseService = SupabaseService();
  final r2StorageService = R2StorageService();
  final renderBackendService = RenderBackendService();
  final dynamicAuthService = DynamicAuthService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthController(
            supabaseService: supabaseService,
            dynamicAuthService: dynamicAuthService,
            renderBackendService: renderBackendService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => FeedController(
            supabaseService: supabaseService,
            r2StorageService: r2StorageService,
            renderBackendService: renderBackendService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PetController(
            supabaseService: supabaseService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LanguageController(),
        ),
      ],
      child: const PawtbookApp(),
    ),
  );
}

class PawtbookApp extends StatelessWidget {
  const PawtbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(), // TikTok Guest-First Entry
    );
  }
}
