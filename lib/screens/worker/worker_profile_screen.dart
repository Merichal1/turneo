import 'package:flutter/material.dart';

class WorkerProfileScreen extends StatelessWidget {
  const WorkerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: SingleChildScrollView(
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
                    const CircleAvatar(
                      radius: 30,
                      child: Text(
                        'AG',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Antonio García',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Camarero / Cocinero',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Eventos Premium S.L.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // TODO: editar foto / datos básicos
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // DATOS PERSONALES
              _SectionCard(
                title: 'Datos personales',
                children: const [
                  _ProfileRow(
                    icon: Icons.email_outlined,
                    label: 'Correo electrónico',
                    value: 'antonio.garcia@example.com',
                  ),
                  _ProfileRow(
                    icon: Icons.phone_outlined,
                    label: 'Teléfono',
                    value: '+34 600 123 456',
                  ),
                  _ProfileRow(
                    icon: Icons.badge_outlined,
                    label: 'DNI / NIE',
                    value: '12345678A',
                  ),
                  _ProfileRow(
                    icon: Icons.cake_outlined,
                    label: 'Fecha de nacimiento',
                    value: '12 marzo 2001',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // DATOS LABORALES
              _SectionCard(
                title: 'Datos laborales',
                children: const [
                  _ProfileRow(
                    icon: Icons.work_outline,
                    label: 'Rol principal',
                    value: 'Camarero',
                  ),
                  _ProfileRow(
                    icon: Icons.work_history_outlined,
                    label: 'Experiencia en la plataforma',
                    value: '2 años',
                  ),
                  _ProfileRow(
                    icon: Icons.fact_check_outlined,
                    label: 'Eventos completados',
                    value: '38',
                  ),
                  _ProfileRow(
                    icon: Icons.euro_outlined,
                    label: 'Último pago',
                    value: '120€ · hace 5 días',
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
                    onTap: () {
                      // TODO: navegar a pantalla de cambio de contraseña
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
                      // TODO: gestionar sesiones
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // OPCIONES DE LA APP / CERRAR SESIÓN
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
                    value: true,
                    onChanged: (v) {
                      // TODO: actualizar preferencia
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: lógica real de logout
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
