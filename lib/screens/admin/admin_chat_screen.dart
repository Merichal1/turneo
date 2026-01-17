import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/trabajador.dart';

class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({super.key});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  // ====== THEME (Turneo / Login) ======
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  final String empresaId = AppConfig.empresaId;

  Trabajador? _selectedWorker;
  String _searchText = '';

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Referencia a la colección de chats
  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('chats_trabajadores');

  /// Envía un mensaje como ADMIN al trabajador seleccionado
  Future<void> _sendMessage() async {
    final worker = _selectedWorker;
    if (worker == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final now = DateTime.now();
    final chatDoc = _chatsCollection.doc(worker.id);
    final mensajesColl = chatDoc.collection('mensajes');

    final batch = FirebaseFirestore.instance.batch();

    // Añadimos mensaje
    final msgRef = mensajesColl.doc();
    batch.set(msgRef, {
      'texto': text,
      'enviadoPor': 'admin',
      'creadoEn': Timestamp.fromDate(now),
    });

    // Aseguramos/actualizamos documento de chat
    final nombreTrabajador =
        '${worker.nombre ?? ''} ${worker.apellidos ?? ''}'.trim();

    batch.set(
      chatDoc,
      {
        'trabajadorId': worker.id,
        'trabajadorNombre': nombreTrabajador,
        'ultimoMensaje': text,
        'ultimoMensajePor': 'admin',
        'ultimoMensajeEn': Timestamp.fromDate(now),
        'creadoEn': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    // Scroll al final
    await Future.delayed(const Duration(milliseconds: 150));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: _bg,
        title: const Text(
          'Chat',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  currentUser.email ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (isWide) {
            // ===== WEB / ESCRITORIO =====
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 320,
                    child: _WorkersPanel(
                      empresaId: empresaId,
                      chatsCollection: _chatsCollection,
                      selectedWorker: _selectedWorker,
                      searchText: _searchText,
                      onSearchChanged: (v) => setState(() => _searchText = v),
                      onSelectWorker: (t) => setState(() => _selectedWorker = t),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ConversationPanel(
                      empresaId: empresaId,
                      selectedWorker: _selectedWorker,
                      scrollController: _scrollController,
                      messageController: _messageController,
                      onSend: _sendMessage,
                    ),
                  ),
                ],
              ),
            );
          }

          // ===== MÓVIL / TABLET =====
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              children: [
                // Barra superior: seleccionar trabajador
                _MobileTopBar(
                  selectedWorker: _selectedWorker,
                  onTapSelect: () => _openWorkersSheet(context),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _ConversationPanel(
                    empresaId: empresaId,
                    selectedWorker: _selectedWorker,
                    scrollController: _scrollController,
                    messageController: _messageController,
                    onSend: _sendMessage,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openWorkersSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.82,
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Trabajadores',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _textDark,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _WorkersPanel(
                      empresaId: empresaId,
                      chatsCollection: _chatsCollection,
                      selectedWorker: _selectedWorker,
                      searchText: _searchText,
                      onSearchChanged: (v) => setState(() => _searchText = v),
                      onSelectWorker: (t) {
                        setState(() => _selectedWorker = t);
                        Navigator.of(context).pop();
                      },
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ======================================================
// WORKERS PANEL (lista izquierda / bottomsheet en móvil)
// ======================================================

class _WorkersPanel extends StatelessWidget {
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  final String empresaId;
  final CollectionReference<Map<String, dynamic>> chatsCollection;
  final Trabajador? selectedWorker;
  final String searchText;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Trabajador> onSelectWorker;
  final bool compact;

  const _WorkersPanel({
    required this.empresaId,
    required this.chatsCollection,
    required this.selectedWorker,
    required this.searchText,
    required this.onSearchChanged,
    required this.onSelectWorker,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              children: [
                Row(
                  children: const [
                    Icon(Icons.people_alt_outlined, size: 18, color: _textDark),
                    SizedBox(width: 8),
                    Text(
                      'Trabajadores',
                      style: TextStyle(
                        color: _textDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: 'Buscar trabajador...',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _blue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (value) => onSearchChanged(value.toLowerCase()),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Expanded(
            child: StreamBuilder<List<Trabajador>>(
              stream: FirestoreService.instance.listenTrabajadores(empresaId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final trabajadores = (snapshot.data ?? []).where((t) {
                  final nombre = ('${t.nombre ?? ''} ${t.apellidos ?? ''}').toLowerCase();
                  if (searchText.isEmpty) return true;
                  return nombre.contains(searchText);
                }).toList();

                if (trabajadores.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No hay trabajadores que coincidan con la búsqueda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: trabajadores.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final t = trabajadores[index];
                    final isSelected = selectedWorker?.id == t.id;
                    final nombre = ('${t.nombre ?? ''} ${t.apellidos ?? ''}').trim();
                    final rol = t.puesto ?? '';

                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: chatsCollection.doc(t.id).snapshots(),
                      builder: (context, chatSnap) {
                        String lastMsg = '';
                        String timeText = '';

                        if (chatSnap.hasData && chatSnap.data!.exists) {
                          final data = chatSnap.data!.data() ?? {};
                          lastMsg = (data['ultimoMensaje'] as String?) ?? '';
                          final ts = data['ultimoMensajeEn'] as Timestamp?;
                          if (ts != null) {
                            final dt = ts.toDate();
                            final h = dt.hour.toString().padLeft(2, '0');
                            final m = dt.minute.toString().padLeft(2, '0');
                            timeText = '$h:$m';
                          }
                        }

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onSelectWorker(t),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSelected ? const Color(0xFFBFDBFE) : _border),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isSelected ? const Color(0xFFDBEAFE) : const Color(0xFFE5E7EB),
                                  child: Text(
                                    _initial(nombre),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: _textDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombre.isEmpty ? 'Sin nombre' : nombre,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: _textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      if (rol.isNotEmpty)
                                        Text(
                                          rol,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: _textGrey,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      if (lastMsg.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          lastMsg,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF94A3B8),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (timeText.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    timeText,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _initial(String nombreCompleto) {
    if (nombreCompleto.trim().isEmpty) return '?';
    return nombreCompleto.trim()[0].toUpperCase();
  }
}

// =============================
// CONVERSATION PANEL (derecha)
// =============================

class _ConversationPanel extends StatelessWidget {
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  final String empresaId;
  final Trabajador? selectedWorker;
  final ScrollController scrollController;
  final TextEditingController messageController;
  final VoidCallback onSend;

  const _ConversationPanel({
    required this.empresaId,
    required this.selectedWorker,
    required this.scrollController,
    required this.messageController,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedWorker == null) {
      return Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Selecciona un trabajador para empezar a chatear.',
              style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _ChatHeader(worker: selectedWorker!),
          const Divider(height: 1, color: _border),
          Expanded(
            child: _ChatMessages(
              empresaId: empresaId,
              worker: selectedWorker!,
              scrollController: scrollController,
            ),
          ),
          const Divider(height: 1, color: _border),
          _ChatInput(
            controller: messageController,
            onSend: onSend,
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);

  final Trabajador worker;

  const _ChatHeader({required this.worker});

  @override
  Widget build(BuildContext context) {
    final nombre = ('${worker.nombre ?? ''} ${worker.apellidos ?? ''}').trim();
    final rol = worker.puesto ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFEFF6FF),
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: _textDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre.isEmpty ? 'Trabajador' : nombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                if (rol.isNotEmpty)
                  Text(
                    rol,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textGrey,
                      fontWeight: FontWeight.w600,
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

class _ChatMessages extends StatelessWidget {
  static const Color _blue = Color(0xFF2563EB);

  final String empresaId;
  final Trabajador worker;
  final ScrollController scrollController;

  const _ChatMessages({
    required this.empresaId,
    required this.worker,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final chatDoc = FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('chats_trabajadores')
        .doc(worker.id);

    final mensajesColl = chatDoc.collection('mensajes');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: mensajesColl.orderBy('creadoEn').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No hay mensajes todavía.\nEscribe el primer mensaje al trabajador.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final texto = (data['texto'] as String?) ?? '';
            final enviadoPor = (data['enviadoPor'] as String?) ?? 'worker';
            final ts = data['creadoEn'] as Timestamp?;
            String timeText = '';
            if (ts != null) {
              final dt = ts.toDate();
              final h = dt.hour.toString().padLeft(2, '0');
              final m = dt.minute.toString().padLeft(2, '0');
              timeText = '$h:$m';
            }

            final isMe = enviadoPor == 'admin';

            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? _blue : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 6),
                      bottomRight: Radius.circular(isMe ? 6 : 16),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 10,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        texto,
                        style: TextStyle(
                          color: isMe ? Colors.white : const Color(0xFF111827),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ChatInput extends StatelessWidget {
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _blue = Color(0xFF2563EB);

  final TextEditingController controller;
  final VoidCallback onSend;

  const _ChatInput({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje…',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: EdgeInsets.zero,
                elevation: 0,
              ),
              onPressed: onSend,
              child: const Icon(Icons.send, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================
// MÓVIL: barra superior
// ============================

class _MobileTopBar extends StatelessWidget {
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);

  final Trabajador? selectedWorker;
  final VoidCallback onTapSelect;

  const _MobileTopBar({
    required this.selectedWorker,
    required this.onTapSelect,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = selectedWorker == null
        ? 'Seleccionar trabajador'
        : ('${selectedWorker!.nombre ?? ''} ${selectedWorker!.apellidos ?? ''}').trim();

    final rol = selectedWorker?.puesto ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTapSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
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
            const Icon(Icons.people_alt_outlined, color: _textDark),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (selectedWorker != null && rol.isNotEmpty)
                    Text(
                      rol,
                      style: const TextStyle(
                        color: _textGrey,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.expand_more, color: _textGrey),
          ],
        ),
      ),
    );
  }
}
