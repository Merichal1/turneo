import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class WorkerChatScreen extends StatefulWidget {
  const WorkerChatScreen({super.key});

  @override
  State<WorkerChatScreen> createState() => _WorkerChatScreenState();
}

class _WorkerChatScreenState extends State<WorkerChatScreen> {
  final String empresaId = AppConfig.empresaId;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> _chatDocFor(String trabajadorId) {
    return FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('chats_trabajadores');
  }

  Future<void> _sendMessage(String trabajadorId) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final now = DateTime.now();
    final chatDoc = _chatDocFor(trabajadorId).doc(trabajadorId);
    final mensajesColl = chatDoc.collection('mensajes');

    final batch = FirebaseFirestore.instance.batch();

    // Añadimos mensaje
    final msgRef = mensajesColl.doc();
    batch.set(msgRef, {
      'texto': text,
      'enviadoPor': 'worker',
      'creadoEn': Timestamp.fromDate(now),
    });

    batch.set(
      chatDoc,
      {
        'trabajadorId': trabajadorId,
        // nombre se podría guardar/actualizar desde otro sitio si quieres
        'ultimoMensaje': text,
        'ultimoMensajePor': 'worker',
        'ultimoMensajeEn': Timestamp.fromDate(now),
        'creadoEn': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Debes iniciar sesión como trabajador.'),
        ),
      );
    }

    final trabajadorId = user.uid;

    final chatDoc = _chatDocFor(trabajadorId).doc(trabajadorId);
    final mensajesColl = chatDoc.collection('mensajes');

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Chat con la empresa',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Cabecera ligera
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            width: double.infinity,
            child: const Text(
              'Usa este chat para hablar con administradores y coordinadores de tus eventos.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const Divider(height: 1),
          // Mensajes
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  mensajesColl.orderBy('creadoEn').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Todavía no tienes mensajes.\n'
                        'Cuando un admin te escriba o tú envíes uno, aparecerá aquí.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final texto = (data['texto'] as String?) ?? '';
                    final enviadoPor =
                        (data['enviadoPor'] as String?) ?? 'admin';
                    final ts = data['creadoEn'] as Timestamp?;
                    String timeText = '';
                    if (ts != null) {
                      final dt = ts.toDate();
                      final h =
                          dt.hour.toString().padLeft(2, '0');
                      final m =
                          dt.minute.toString().padLeft(2, '0');
                      timeText = '$h:$m';
                    }

                    final isMe = enviadoPor == 'worker';

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin:
                            const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width *
                                  0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFF3B82F6)
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
                                fontSize: 14,
                                color: isMe
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeText,
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            color: Colors.white,
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
                      controller: _messageController,
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
                  onPressed: () => _sendMessage(trabajadorId),
                  icon: const Icon(Icons.send),
                  color: const Color(0xFF2563EB),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
