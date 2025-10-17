import 'package:flutter/material.dart';

/// Navega con: Navigator.pushNamed(context, '/error', arguments: 'Mensaje opcional');
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final message = (args is String && args.trim().isNotEmpty)
        ? args.trim()
        : 'Ha ocurrido un error inesperado.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(
                    onPressed: () {
                      // Acción por defecto: reintentar = recargar ruta anterior si existe.
                      Navigator.of(context).maybePop();
                    },
                    child: const Text('Reintentar'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      // Ir a la pantalla inicial (ajusta si quieres otro destino)
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/_debug', // o Routes.splash en release
                        (route) => false,
                      );
                    },
                    child: const Text('Ir al inicio'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
