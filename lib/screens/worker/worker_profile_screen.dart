import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_config.dart';

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({super.key});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  // ====== THEME (Turneo / Admin) ======
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  final _picker = ImagePicker();
  bool _uploadingPhoto = false;

  DocumentReference<Map<String, dynamic>> _workerRef(String uid) {
    return FirebaseFirestore.instance
        .collection('empresas')
        .doc(AppConfig.empresaId)
        .collection('trabajadores')
        .doc(uid);
  }

  Reference _workerPhotoRef(String uid) {
    return FirebaseStorage.instance
        .ref()
        .child('empresas')
        .child(AppConfig.empresaId)
        .child('trabajadores')
        .child(uid)
        .child('profile.jpg');
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
      final cleaned = roles
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return cleaned.isEmpty ? '—' : cleaned.join(' / ');
    }
    if (roles is String && roles.trim().isNotEmpty) return roles.trim();
    if (rolFallback is String && rolFallback.trim().isNotEmpty) {
      return rolFallback.trim();
    }
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

  Future<void> _changePhoto({
    required BuildContext context,
    required String uid,
    required DocumentReference<Map<String, dynamic>> ref,
  }) async {
    // 1) Preguntar al usuario si cámara o galería
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Foto de perfil',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de la galería'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Hacer una foto'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      setState(() => _uploadingPhoto = true);

      // 2) Elegir/capturar imagen
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1024,
      );

      if (picked == null) {
        setState(() => _uploadingPhoto = false);
        return;
      }

      // 3) Subir a Storage
      final Uint8List bytes = await picked.readAsBytes();
      final photoRef = _workerPhotoRef(uid);

      await photoRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final url = await photoRef.getDownloadURL();

      // 4) Guardar url en Firestore (campo: photoUrl)
      await ref.set(
        {
          'photoUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto actualizada ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error subiendo foto: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SafeArea(
        child: Scaffold(
          backgroundColor: _bg,
          body: Center(child: Text('Inicia sesión')),
        ),
      );
    }

    final ref = _workerRef(user.uid);

    return SafeArea(
      child: Scaffold(
        backgroundColor: _bg,
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: ref.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snap.data?.data() ?? <String, dynamic>{};

            final nombre = _safeText(data['nombre']);
            final apellidos = _safeText(data['apellidos']);
            final fullName =
                (('$nombre $apellidos').trim().replaceAll(RegExp(r'\s+'), ' '));
            final displayName =
                (fullName.trim().isEmpty || fullName == '— —') ? '—' : fullName;

            final rolesText = _rolesToText(data['roles'], data['rol']);
            final empresaNombre = _safeText(data['empresaNombre']);

            final email =
                (user.email ?? '').trim().isEmpty ? '—' : user.email!.trim();
            final telefono = _safeText(data['telefono']);
            final dni = _safeText(data['dni']);
            final nacimiento = _formatBirth(data['fechaNacimiento']);

            final bool notificacionesPush = (data['notificacionesPush'] is bool)
                ? data['notificacionesPush'] as bool
                : true;

            final photoUrl = (data['photoUrl'] ?? '').toString().trim();
            final initials = _initialsFromName(
              displayName == '—' ? '' : displayName,
              user.email ?? '',
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== Header =====
                  const Text(
                    'Perfil',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tu información personal y ajustes',
                    style: TextStyle(
                      color: _textGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ===== Card principal =====
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: const Color(0xFFEFF6FF),
                              backgroundImage:
                                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                              child: photoUrl.isNotEmpty
                                  ? null
                                  : Text(
                                      initials,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: _textDark,
                                      ),
                                    ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: InkWell(
                                onTap: _uploadingPhoto
                                    ? null
                                    : () => _changePhoto(
                                          context: context,
                                          uid: user.uid,
                                          ref: ref,
                                        ),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _blue,
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: _uploadingPhoto
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt_outlined,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rolesText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textGrey,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                empresaNombre == '—'
                                    ? 'Mi empresa'
                                    : empresaNombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textGrey,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _openEditSheet(
                            context: context,
                            ref: ref,
                            existing: data,
                            email: email,
                          ),
                          icon: const Icon(Icons.edit_outlined, color: _blue),
                          tooltip: 'Editar',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ===== Datos personales =====
                  _SectionCard(
                    title: 'Datos personales',
                    icon: Icons.badge_outlined,
                    children: [
                      _ProfileRow(
                        icon: Icons.email_outlined,
                        label: 'Correo',
                        value: email,
                      ),
                      _ProfileRow(
                        icon: Icons.phone_outlined,
                        label: 'Teléfono',
                        value: telefono,
                      ),
                      _ProfileRow(
                        icon: Icons.credit_card_outlined,
                        label: 'DNI / NIE',
                        value: dni,
                      ),
                      _ProfileRow(
                        icon: Icons.cake_outlined,
                        label: 'Nacimiento',
                        value: nacimiento,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ===== Datos laborales =====
                  _SectionCard(
                    title: 'Datos laborales',
                    icon: Icons.work_outline,
                    children: [
                      _ProfileRow(
                        icon: Icons.work_outline,
                        label: 'Rol principal',
                        value: rolesText == '—'
                            ? '—'
                            : rolesText.split(' / ').first,
                      ),
                      _ProfileRow(
                        icon: Icons.layers_outlined,
                        label: 'Roles',
                        value: rolesText,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ===== Seguridad =====
                  _SectionCard(
                    title: 'Seguridad',
                    icon: Icons.lock_outline,
                    children: [
                      _ActionTile(
                        icon: Icons.lock_reset_outlined,
                        title: 'Cambiar contraseña',
                        subtitle: 'Te enviamos un email para restablecerla',
                        onTap: () async {
                          final mail = user.email;
                          if (mail == null || mail.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tu usuario no tiene email.'),
                              ),
                            );
                            return;
                          }
                          await FirebaseAuth.instance
                              .sendPasswordResetEmail(email: mail.trim());
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Te envié un email para cambiar la contraseña.'),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      _ActionTile(
                        icon: Icons.devices_other_outlined,
                        title: 'Dispositivos activos',
                        subtitle: 'Gestión de sesiones (pendiente)',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Gestión de sesiones (pendiente)'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ===== Cuenta =====
                  _SectionCard(
                    title: 'Cuenta',
                    icon: Icons.settings_outlined,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: SwitchListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          title: const Text(
                            'Notificaciones push',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: const Text(
                            'Recibir avisos de nuevos eventos y cambios',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          value: notificacionesPush,
                          onChanged: (v) async {
                            await ref.set(
                              {'notificacionesPush': v},
                              SetOptions(merge: true),
                            );
                          },
                        ),
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
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text(
                            'Cerrar sesión',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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
    final nombreCtrl =
        TextEditingController(text: (existing['nombre'] ?? '').toString());
    final apellidosCtrl =
        TextEditingController(text: (existing['apellidos'] ?? '').toString());
    final telefonoCtrl =
        TextEditingController(text: (existing['telefono'] ?? '').toString());
    final dniCtrl =
        TextEditingController(text: (existing['dni'] ?? '').toString());
    final empresaCtrl = TextEditingController(
        text: (existing['empresaNombre'] ?? '').toString());

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Editar perfil',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _textDark,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(email,
                    style: const TextStyle(
                        color: _textGrey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),

                _Input(controller: nombreCtrl, label: 'Nombre'),
                const SizedBox(height: 10),
                _Input(controller: apellidosCtrl, label: 'Apellidos'),
                const SizedBox(height: 10),
                _Input(
                  controller: telefonoCtrl,
                  label: 'Teléfono',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                _Input(controller: dniCtrl, label: 'DNI / NIE'),
                const SizedBox(height: 10),

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
                    child: _Input(
                      label: 'Fecha de nacimiento',
                      hintText: birth == null
                          ? 'Selecciona fecha'
                          : '${birth!.day.toString().padLeft(2, '0')}/${birth!.month.toString().padLeft(2, '0')}/${birth!.year}',
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                _Input(
                  controller: rolesCtrl,
                  label: 'Roles (separados por coma)',
                  hintText: 'camarero, cocinero',
                ),
                const SizedBox(height: 10),
                _Input(controller: empresaCtrl, label: 'Empresa'),

                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
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
                        if (rolesRaw.isNotEmpty) 'rol': rolesRaw.first,
                        if (birth != null)
                          'fechaNacimiento': Timestamp.fromDate(birth!),
                      };

                      await ref.set(payload, SetOptions(merge: true));

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Perfil guardado')),
                        );
                      }
                    },
                    child: const Text(
                      'Guardar cambios',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
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

// ────────────────────────── UI components ──────────────────────────
// (tus widgets auxiliares igual que los tienes)

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _textGrey),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _textDark,
                ),
              ),
            ],
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

  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _textGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textGrey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _textDark,
                    fontWeight: FontWeight.w800,
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textGrey = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: _textGrey),
        title: const SizedBox.shrink(),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: _textGrey),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const _Input({
    this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.suffixIcon,
  });

  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(
          color: _textGrey,
          fontWeight: FontWeight.w700,
        ),
        isDense: true,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
