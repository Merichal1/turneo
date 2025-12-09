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
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Chat (Admin)',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        actions: [
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  currentUser.email ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Row(
        children: [
          // Panel izquierdo: lista de trabajadores + buscador
          SizedBox(
            width: 260,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: 'Buscar trabajador...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchText = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<Trabajador>>(
                    stream: FirestoreService.instance.listenTrabajadores(empresaId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final trabajadores = (snapshot.data ?? [])
                          .where((t) {
                            final nombre =
                                ('${t.nombre ?? ''} ${t.apellidos ?? ''}')
                                    .toLowerCase();
                            if (_searchText.isEmpty) return true;
                            return nombre.contains(_searchText);
                          })
                          .toList();

                      if (trabajadores.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'No hay trabajadores que coincidan con la búsqueda.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: trabajadores.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final t = trabajadores[index];
                          final isSelected = _selectedWorker?.id == t.id;
                          final nombre =
                              ('${t.nombre ?? ''} ${t.apellidos ?? ''}')
                                  .trim();
                          final rol = t.puesto ?? '';

                          return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            stream: _chatsCollection.doc(t.id).snapshots(),
                            builder: (context, chatSnap) {
                              String lastMsg = '';
                              String timeText = '';
                              int unreadCount = 0; // lo podríamos usar más tarde

                              if (chatSnap.hasData &&
                                  chatSnap.data!.exists) {
                                final data = chatSnap.data!.data() ?? {};
                                lastMsg =
                                    (data['ultimoMensaje'] as String?) ?? '';
                                final ts = data['ultimoMensajeEn']
                                    as Timestamp?;
                                if (ts != null) {
                                  final dt = ts.toDate();
                                  final h = dt.hour
                                      .toString()
                                      .padLeft(2, '0');
                                  final m = dt.minute
                                      .toString()
                                      .padLeft(2, '0');
                                  timeText = '$h:$m';
                                }
                              }

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedWorker = t;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF111827)
                                            .withOpacity(0.05)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        child: Text(
                                          nombre.isNotEmpty
                                              ? nombre[0].toUpperCase()
                                              : '?',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nombre.isEmpty
                                                  ? 'Sin nombre'
                                                  : nombre,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? const Color(
                                                        0xFF111827)
                                                    : const Color(
                                                        0xFF111827),
                                              ),
                                            ),
                                            if (rol.isNotEmpty)
                                              Text(
                                                rol,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF6B7280),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow
                                                    .ellipsis,
                                              ),
                                            if (lastMsg.isNotEmpty)
                                              Text(
                                                lastMsg,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF9CA3AF),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow
                                                    .ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          if (timeText.isNotEmpty)
                                            Text(
                                              timeText,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFFA1A1AA),
                                              ),
                                            ),
                                          if (unreadCount > 0)
                                            Container(
                                              margin:
                                                  const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    const Color(0xFF111827),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        999),
                                              ),
                                              child: Text(
                                                '$unreadCount',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
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
          ),

          const VerticalDivider(width: 1),

          // Panel derecho: conversación
          Expanded(
            child: _selectedWorker == null
                ? const Center(
                    child: Text(
                      'Selecciona un trabajador para empezar a chatear.',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // Cabecera de la conversación
                      _ChatHeader(worker: _selectedWorker!),
                      const Divider(height: 1),
                      // Mensajes
                      Expanded(
                        child: _ChatMessages(
                          empresaId: empresaId,
                          worker: _selectedWorker!,
                          scrollController: _scrollController,
                        ),
                      ),
                      // Input
                      _ChatInput(
                        controller: _messageController,
                        onSend: _sendMessage,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final Trabajador worker;

  const _ChatHeader({required this.worker});

  @override
  Widget build(BuildContext context) {
    final nombre =
        ('${worker.nombre ?? ''} ${worker.apellidos ?? ''}').trim();
    final rol = worker.puesto ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (rol.isNotEmpty)
                  Text(
                    rol,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
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
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No hay mensajes todavía.\nEscribe el primer mensaje al trabajador.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              alignment:
                  isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.5,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      texto,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            isMe ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
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
  final TextEditingController controller;
  final VoidCallback onSend;

  const _ChatInput({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
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
          const SizedBox(width: 8),
          IconButton(
            onPressed: onSend,
            icon: const Icon(Icons.send),
            color: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }
}
