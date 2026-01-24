import 'package:flutter/widgets.dart';

// COMMON
import '../screens/common/splash_screen.dart';
import '../screens/common/error_screen.dart';

// AUTH (NUEVO)
import '../screens/auth/turneo_start_screen.dart';
import '../screens/Login/login_screen.dart';
// 👉 OJO: aquí pon el import real de tu registro NUEVO
import '../screens/Signup/signup_screen.dart'; // si tu registro moderno está aquí
// si NO existe, me lo dices y te lo creo en 1 archivo.

// ADMIN
import '../screens/admin/admin_shell_screen.dart';
import '../screens/admin/admin_home_screen.dart';
import '../screens/admin/admin_events_screen.dart';
import '../screens/admin/admin_workers_screen.dart';
import '../screens/admin/admin_chat_screen.dart';
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

  // Auth nueva
  static const welcome = '/auth/welcome';
  static const loginZip = '/auth/login';
  static const registerZip = '/auth/register';

  // Admin
  static const adminShell = '/admin';
  static const adminHome = '/admin/home';
  static const adminEvents = '/admin/events';
  static const adminWorkers = '/admin/workers';
  static const adminChat = '/admin/chat';
  static const adminDatabase = '/admin/database';
  static const adminImport = '/admin/import';
  static const adminPaymentsHistory = '/admin/payments-history';
  static const adminNotifications = '/admin/notifications';

  // Worker
  static const workerHome = '/worker/home';
  static const workerEvents = '/worker/events';

  static Map<String, WidgetBuilder> builders = {
    debugLauncher: (_) => const DebugLauncherScreen(),

    // Common
    splash: (_) => const SplashScreen(),
    error: (_) => const ErrorScreen(),

    // Auth NUEVA
    welcome: (_) => const TurneoStartScreen(),
    loginZip: (_) => const LoginScreenModern(),
    registerZip: (_) => const SignUpScreen(), // ⚠️ si tu clase se llama diferente, cámbiala aquí

    // Admin
    adminShell: (_) => const AdminShellScreen(),
    adminHome: (_) => const AdminHomeScreen(),
    adminEvents: (_) => const AdminEventsScreen(),
    adminWorkers: (_) => const AdminWorkersScreen(),
    adminChat: (_) => const AdminChatScreen(),
    adminImport: (_) => const AdminImportScreen(),
    adminPaymentsHistory: (_) => const AdminPaymentsHistoryScreen(),
    adminNotifications: (_) => const AdminNotificacionesScreen(),

    // Worker
    workerHome: (_) => const WorkerHomeScreen(),
    workerEvents: (_) => const WorkerEventsScreen(),
  };
}
