// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

// Config & rutas
import 'config/firebase_options.dart';
import 'routes/app_routes.dart';

// Providers (usa alias para evitar choque de nombres con tus servicios)
import 'providers/auth_provider.dart' as prov;
import 'providers/user_provider.dart';
import 'providers/event_provider.dart';

// Tema
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TurneoApp());
}

class TurneoApp extends StatelessWidget {
  const TurneoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AUTH PROVIDER (nuestro, el de providers/)
        ChangeNotifierProvider<prov.AuthProvider>(
          create: (_) {
            final p = prov.AuthProvider(FirebaseAuth.instance);
            p.start(); // escucha authStateChanges y carga claims (companyId, role)
            return p;
          },
        ),

        // USER PROVIDER depende de companyId -> se crea tras login
        ChangeNotifierProxyProvider<prov.AuthProvider, UserProvider?>(
          create: (_) => null,
          update: (_, auth, prev) {
            final cId = auth.companyId;
            if (!auth.isSignedIn || cId == null) return null;
            return prev ??
                UserProvider(
                  db: FirebaseFirestore.instance,
                  companyId: cId,
                );
          },
        ),

        // EVENT PROVIDER depende de companyId -> se crea tras login
        ChangeNotifierProxyProvider<prov.AuthProvider, EventProvider?>(
          create: (_) => null,
          update: (_, auth, prev) {
            final cId = auth.companyId;
            if (!auth.isSignedIn || cId == null) return null;
            return prev ??
                EventProvider(
                  db: FirebaseFirestore.instance,
                  companyId: cId,
                );
          },
        ),
      ],
      child: MaterialApp(
        title: 'Turneo',
        debugShowCheckedModeBanner: !kReleaseMode,
        theme: AppTheme.vogueGlovoLight,
        darkTheme: AppTheme.vogueGlovoDark,
        themeMode: ThemeMode.system,

        // Mantengo tu ruta inicial actual:
        initialRoute: Routes.welcome, // '/_debug'

        // 👉 Si quieres probar directamente la nueva UI del ZIP:
        // initialRoute: Routes.welcome,

        routes: Routes.builders,

        onUnknownRoute: (_) => MaterialPageRoute(
          builder: Routes.builders[Routes.error]!,
          settings: const RouteSettings(name: Routes.error),
        ),
      ),
    );
  }
}
