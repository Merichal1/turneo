import 'package:flutter/material.dart';
// import '../../widgets/file_widget.dart'; // si ya lo tienes

class AdminImportScreen extends StatelessWidget {
  const AdminImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: usar tu FileWidget + StorageService para subir, y Cloud Functions para procesar
    return Scaffold(
      appBar: AppBar(title: const Text('Importar / Soporte')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historial de importaciones', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('import_2025_10_01.csv'),
              subtitle: const Text('Registros: 120 • OK'),
              trailing: IconButton(
                icon: const Icon(Icons.download_outlined),
                onPressed: () {},
              ),
            ),
            const Divider(height: 32),
            Text('Subir nuevo archivo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: seleccionar y subir (StorageService.uploadFile)
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Seleccionar archivo'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                // TODO: disparar Cloud Function para importar
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Procesar importación'),
            ),
          ],
        ),
      ),
    );
  }
}
