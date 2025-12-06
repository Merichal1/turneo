import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart'; // 👈 IMPORTANTE

import 'config/firebase_options.dart';
import 'auth_ui/Screens/Welcome/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 👇 ESTO ES LO QUE ARREGLA TU ERROR DEL LOCALE
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
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}
