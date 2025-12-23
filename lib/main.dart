import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 👈 AÑADIDO

import 'config/firebase_options.dart';
import 'auth_ui/Screens/Welcome/welcome_screen.dart';
import 'routes/app_routes.dart'; // NUEVO

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializar formato de fechas en español
  await initializeDateFormatting('es_ES', null);

  runApp(const TurneoApp());
}

class TurneoApp extends StatelessWidget {
  const TurneoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Turneo',
      // 👇 CONFIGURACIÓN PARA IDIOMA ESPAÑOL
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
      ],
      locale: const Locale('es', 'ES'),
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        useMaterial3: true,
      ),
      routes: Routes.builders, // NUEVO
      home: const WelcomeScreen(),
    );
  }
}
