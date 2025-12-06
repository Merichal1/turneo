import 'package:flutter/widgets.dart';

// AUTH NUEVA (ZIP)
import '../auth_ui/Screens/Welcome/welcome_screen.dart' as zip;
import '../auth_ui/Screens/Login/login_screen.dart' as zip;
import '../auth_ui/Screens/Signup/signup_screen.dart' as zip;

// COMMON
import '../screens/common/splash_screen.dart';
import '../screens/common/error_screen.dart';

// ADMIN
import '../screens/admin/admin_shell_screen.dart';
import '../screens/admin/admin_home_screen.dart';
import '../screens/admin/admin_events_screen.dart';
import '../screens/admin/admin_database_screen.dart' hide AdminEventScreen;
import '../screens/admin/admin_import_screen.dart';
import '../screens/admin/admin_payments_history_screen.dart';
import '../screens/admin/admin_notificaciones_screen.dart';

// WORKER
import '../screens/worker/worker_home_screen.dart';
import '../screens/worker/worker_event_screen.dart';

// DEBUG
import '../screens/_debug_launcher_screen.dart';

class Routes {
  // Debug
  static const debugLauncher = '/_debug';

  // Common
  static const splash = '/splash';
  static const error = '/error';

  // Auth (original)
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const changePassword = '/auth/change-password';

  // Auth nueva (ZIP)
  static const welcome = '/auth/welcome';
  static const loginZip = '/auth/login-zip';
  static const registerZip = '/auth/register-zip';

  // Admin
  static const adminShell = '/admin';
  static const adminHome = '/admin/home';
  static const adminEvents = '/admin/events';
  static const adminDatabase = '/admin/database';
  static const adminImport = '/admin/import';
  static const adminPaymentsHistory = '/admin/payments-history';
  static const adminNotifications = '/admin/notifications';

  // Worker
  static const workerHome = '/worker/home';
  static const workerEvents = '/worker/events';

  /// Mapa de rutas -> builders
  static Map<String, WidgetBuilder> builders = {
    // Debug
    debugLauncher: (_) => const DebugLauncherScreen(),

    // Common
    splash: (_) => const SplashScreen(),
    error: (_) => const ErrorScreen(),

    // AUTH NUEVA (ZIP)
    welcome: (_) => const zip.WelcomeScreen(),
    loginZip: (_) => const zip.LoginScreen(),
    registerZip: (_) => const zip.SignUpScreen(),

    // ADMIN
    adminShell: (_) => const AdminShellScreen(),
    adminHome: (_) => const AdminHomeScreen(),
    adminEvents: (_) => const AdminEventsScreen(),
    adminDatabase: (_) => const AdminDatabaseScreen(),
    adminImport: (_) => const AdminImportScreen(),
    adminPaymentsHistory: (_) => const AdminPaymentsHistoryScreen(),
    adminNotifications: (_) => const AdminNotificacionesScreen(),

    // WORKER
    workerHome: (_) => const WorkerHomeScreen(),
    workerEvents: (_) => const WorkerEventsScreen(),
  };
}
