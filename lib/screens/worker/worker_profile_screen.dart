import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class WorkerProfileScreen extends StatelessWidget {
  const WorkerProfileScreen({super.key});

  DocumentReference<Map<String, dynamic>> _workerRef(String uid) {
    return FirebaseFirestore.instance
        .collection('empresas')
        .doc(AppConfig.empresaId)
        .collection('trabajadores')
        .doc(uid);
  }

  String _initialsFromName(String fullName, String email) {
    final base = fullName.trim().isEmpty ? email : fullName;
    final parts =
        base.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '??';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last =
        (parts.length > 1 && parts.last.isNotEmpty) ? parts.last[0] : '';
    final res = (first + last).toUpperCase();
    return res.isEmpty ? '??' : res;
  }

  String _safeText(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '—' : s;
  }

  String _rolesToText(dynamic roles, dynamic rolFallback) {
    if (roles is List) {
      final cleaned =
          roles.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      return cleaned.isEmpty ? '—' : cleaned.join(' / ');
    }
    if (roles is String && roles.trim().isNotEmpty) return roles.trim();
    if (rolFallback is String && rolFallback.trim().isNotEmpty) return rolFallback.trim();
    return '—';
  }

  String _formatBirth(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      final yy = d.year.toString();
      return '$dd/$mm/$yy';
    }
    return '—';
  }

  DateTime? _birthToDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SafeArea(
        child: Scaffold(
          backgroundColor: Color(0xFFF3F4F6),
          body: Center(child: Text('Inicia sesión')),
        ),
      );
    }

    final ref = _workerRef(user.uid);

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: ref.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snap.data?.data() ?? <String, dynamic>{};

            final nombre = _safeText(data['nombre']);
            final apellidos = _safeText(data['apellidos']);
            final fullName = (('$nombre $apellidos').trim().replaceAll(RegExp(r'\s+'), ' '));
            final displayName =
                (fullName.trim().isEmpty || fullName == '— —') ? '—' : fullName;

            final rolesText = _rolesToText(data['roles'], data['rol']);
            final empresaNombre = _safeText(data['empresaNombre']);

            final email = (user.email ?? '').trim().isEmpty ? '—' : user.email!.trim();
            final telefono = _safeText(data['telefono']);
            final dni = _safeText(data['dni']);
            final nacimiento = _formatBirth(data['fechaNacimiento']);

            final bool notificacionesPush =
                (data['notificacionesPush'] is bool) ? data['notificacionesPush'] as bool : true;

            final initials = _initialsFromName(displayName == '—' ? '' : displayName, user.email ?? '');

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CABECERA
                  Row(
                    children: const [
                      Icon(Icons.person_outline, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Mi perfil',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // TARJETA PRINCIPAL PERFIL
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                          color: Colors.black.withOpacity(0.04),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rolesText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                empresaNombre == '—' ? 'Mi empresa' : empresaNombre,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _openEditSheet(
                            context: context,
                            ref: ref,
                            existing: data,
                            email: email,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // DATOS PERSONALES
                  _SectionCard(
                    title: 'Datos personales',
                    children: [
                      _ProfileRow(
                        icon: Icons.email_outlined,
                        label: 'Correo electrónico',
                        value: email,
                      ),
                      _ProfileRow(
                        icon: Icons.phone_outlined,
                        label: 'Teléfono',
                        value: telefono,
                      ),
                      _ProfileRow(
                        icon: Icons.badge_outlined,
                        label: 'DNI / NIE',
                        value: dni,
                      ),
                      _ProfileRow(
                        icon: Icons.cake_outlined,
                        label: 'Fecha de nacimiento',
                        value: nacimiento,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // DATOS LABORALES (✅ QUITADO "Último pago")
                  _SectionCard(
                    title: 'Datos laborales',
                    children: [
                      _ProfileRow(
                        icon: Icons.work_outline,
                        label: 'Rol principal',
                        value: rolesText == '—' ? '—' : rolesText.split(' / ').first,
                      ),
                      _ProfileRow(
                        icon: Icons.work_history_outlined,
                        label: 'Experiencia en la plataforma',
                        value: '—',
                      ),
                      _ProfileRow(
                        icon: Icons.fact_check_outlined,
                        label: 'Eventos completados',
                        value: '—',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // SEGURIDAD
                  _SectionCard(
                    title: 'Seguridad',
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lock_outline),
                        title: const Text(
                          'Cambiar contraseña',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Actualiza tu contraseña de acceso',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final mail = user.email;
                          if (mail == null || mail.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tu usuario no tiene email.')),
                            );
                            return;
                          }
                          await FirebaseAuth.instance.sendPasswordResetEmail(email: mail.trim());
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Te envié un email para cambiar la contraseña.')),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.devices_other_outlined),
                        title: const Text(
                          'Dispositivos activos',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Cierra sesión en otros dispositivos',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gestión de sesiones (pendiente)')),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // CUENTA
                  _SectionCard(
                    title: 'Cuenta',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Notificaciones push',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Recibir avisos de nuevos eventos y cambios',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        value: notificacionesPush,
                        onChanged: (v) async {
                          await ref.set({'notificacionesPush': v}, SetOptions(merge: true));
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.of(context).popUntil((r) => r.isFirst);
                            }
                          },
                          icon: const Icon(
                            Icons.logout,
                            size: 18,
                            color: Color(0xFFDC2626),
                          ),
                          label: const Text(
                            'Cerrar sesión',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openEditSheet({
    required BuildContext context,
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> existing,
    required String email,
  }) async {
    final nombreCtrl = TextEditingController(text: (existing['nombre'] ?? '').toString());
    final apellidosCtrl = TextEditingController(text: (existing['apellidos'] ?? '').toString());
    final telefonoCtrl = TextEditingController(text: (existing['telefono'] ?? '').toString());
    final dniCtrl = TextEditingController(text: (existing['dni'] ?? '').toString());
    final empresaCtrl = TextEditingController(text: (existing['empresaNombre'] ?? '').toString());

    // roles: permitimos editar como texto "camarero, cocinero"
    String rolesText;
    final rolesExisting = existing['roles'];
    if (rolesExisting is List) {
      rolesText = rolesExisting.map((e) => e.toString()).join(', ');
    } else if (rolesExisting is String) {
      rolesText = rolesExisting;
    } else if (existing['rol'] is String) {
      rolesText = existing['rol'];
    } else {
      rolesText = '';
    }
    final rolesCtrl = TextEditingController(text: rolesText);

    DateTime? birth = _birthToDate(existing['fechaNacimiento']);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Editar perfil',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(email, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),

                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: apellidosCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Apellidos',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dniCtrl,
                  decoration: const InputDecoration(
                    labelText: 'DNI / NIE',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Fecha nacimiento
                GestureDetector(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: birth ?? DateTime(now.year - 20, 1, 1),
                      firstDate: DateTime(1940),
                      lastDate: DateTime(now.year - 14, 12, 31),
                    );
                    if (picked != null) setMState(() => birth = picked);
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Fecha de nacimiento',
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                        hintText: birth == null
                            ? 'Selecciona fecha'
                            : '${birth!.day.toString().padLeft(2, '0')}/${birth!.month.toString().padLeft(2, '0')}/${birth!.year}',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: rolesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Roles (separados por coma)',
                    border: OutlineInputBorder(),
                    hintText: 'camarero, cocinero',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: empresaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Empresa',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      // preparar roles
                      final rolesRaw = rolesCtrl.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();

                      final payload = <String, dynamic>{
                        'nombre': nombreCtrl.text.trim(),
                        'apellidos': apellidosCtrl.text.trim(),
                        'telefono': telefonoCtrl.text.trim(),
                        'dni': dniCtrl.text.trim(),
                        'empresaNombre': empresaCtrl.text.trim(),
                        'roles': rolesRaw,
                        // opcional: rol "principal"
                        if (rolesRaw.isNotEmpty) 'rol': rolesRaw.first,
                        if (birth != null) 'fechaNacimiento': Timestamp.fromDate(birth!),
                      };

                      await ref.set(payload, SetOptions(merge: true));

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Perfil guardado')),
                        );
                      }
                    },
                    child: const Text('Guardar cambios'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── WIDGETS AUXILIARES ──────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
