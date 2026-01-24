import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/trabajador.dart';

class WorkerChatScreen extends StatefulWidget {
  const WorkerChatScreen({super.key});

  @override
  State<WorkerChatScreen> createState() => _WorkerChatScreenState();
}

class _WorkerChatScreenState extends State<WorkerChatScreen>
    with SingleTickerProviderStateMixin {
  // ====== THEME (Turneo / Admin-like) ======
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _soft = Color(0xFFF9FAFB);

  final String empresaId = AppConfig.empresaId;
  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  late final TabController _tab;

  // ---- ADMIN CHAT (legacy) ----
  final TextEditingController _adminMsgCtrl = TextEditingController();
  final ScrollController _adminScroll = ScrollController();

  // ---- WORKERS CHAT ----
  Trabajador? _selected;
  String _searchText = '';
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // Workers chat collection
  CollectionReference<Map<String, dynamic>> get _userChats =>
      FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('chats_usuarios');

  // Admin chat doc (legacy)
  DocumentReference<Map<String, dynamic>> get _adminChatDoc =>
      FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('chats_trabajadores')
          .doc(myUid);

  String _chatIdFor(String a, String b) {
    final pair = [a, b]..sort();
    return '${pair[0]}_${pair[1]}';
  }

  DocumentReference<Map<String, dynamic>>? get _activeChatDoc {
    final other = _selected?.id;
    if (other == null) return null;
    return _userChats.doc(_chatIdFor(myUid, other));
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _adminMsgCtrl.dispose();
    _adminScroll.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // ADMIN CHAT (legacy)
  // -------------------------
  Future<void> _sendAdminMessage() async {
    final text = _adminMsgCtrl.text.trim();
    if (text.isEmpty) return;

    _adminMsgCtrl.clear();

    final now = DateTime.now();
    final msgs = _adminChatDoc.collection('mensajes');

    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      msgs.doc(),
      {
        'texto': text,
        'enviadoPor': myUid,
        'enviadoEn': Timestamp.fromDate(now),
        'creadoEn': Timestamp.fromDate(now), // ✅ orden estable
      },
    );

    batch.set(
      _adminChatDoc,
      {
        'trabajadorId': myUid,
        'ultimoMensaje': text,
        'ultimoMensajePor': myUid,
        'ultimoMensajeEn': Timestamp.fromDate(now),
        'creadoEn': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    await Future.delayed(const Duration(milliseconds: 120));
    if (_adminScroll.hasClients) {
      _adminScroll.animateTo(
        _adminScroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // -------------------------
  // WORKERS CHAT
  // -------------------------
  Future<void> _sendUserMessage() async {
    final chatDoc = _activeChatDoc;
    final other = _selected;
    if (chatDoc == null || other == null) return;

    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();

    final now = DateTime.now();
    final msgs = chatDoc.collection('mensajes');

    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      msgs.doc(),
      {
        'texto': text,
        'enviadoPor': myUid,
        'enviadoEn': Timestamp.fromDate(now),
        'creadoEn': Timestamp.fromDate(now), // ✅ orden estable
      },
    );

    batch.set(
      chatDoc,
      {
        'members': [myUid, other.id],
        'ultimoMensaje': text,
        'ultimoMensajePor': myUid,
        'ultimoMensajeEn': Timestamp.fromDate(now),
        'creadoEn': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    await Future.delayed(const Duration(milliseconds: 120));
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Chat',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: _textDark),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _card,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: _blue,
                unselectedLabelColor: _textGrey,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.admin_panel_settings_outlined, size: 18),
                    text: 'Admin',
                  ),
                  Tab(
                    icon: Icon(Icons.people_alt_outlined, size: 18),
                    text: 'Trabajadores',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ✅ Admin: UNA sola pantalla (no “dos partes”)
          _AdminChatModern(
            empresaId: empresaId,
            myUid: myUid,
            chatDoc: _adminChatDoc,
            controller: _adminMsgCtrl,
            scroll: _adminScroll,
            onSend: _sendAdminMessage,
          ),

          // Trabajadores
          isWide
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: Row(
                    children: [
                      SizedBox(width: 360, child: _WorkersListModern()),
                      const SizedBox(width: 12),
                      Expanded(child: _WorkersChatModern()),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: (_selected == null)
                      ? _WorkersListModern()
                      : _WorkersChatModern(mobileBack: true),
                ),
        ],
      ),
    );
  }

  // =========================
  // Workers list (modern)
  // =========================
  Widget _WorkersListModern() {
    return _CardShell(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Buscar trabajador...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: _soft,
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
              ),
              onChanged: (v) => setState(() => _searchText = v.trim().toLowerCase()),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Trabajador>>(
              stream: FirestoreService.instance.listenTrabajadores(empresaId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error cargando trabajadores:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data!;
                final filtered = all.where((t) {
                  if (t.id == myUid) return false;
                  if (_searchText.isEmpty) return true;
                  final name = (t.nombre).toLowerCase();
                  return name.contains(_searchText);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No hay resultados.',
                        style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final t = filtered[i];
                    final selected = _selected?.id == t.id;
                    final name = t.nombre;

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _selected = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFEFF6FF) : _soft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: selected ? const Color(0xFFC7D2FE) : _border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFEFF6FF),
                              child: Text(
                                (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                                style: const TextStyle(color: _textDark, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name.isEmpty ? 'Sin nombre' : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _textDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                          ],
                        ),
                      ),
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

  // =========================
  // Workers chat panel (modern)
  // =========================
  Widget _WorkersChatModern({bool mobileBack = false}) {
    final t = _selected;
    final chatDoc = _activeChatDoc;

    if (t == null || chatDoc == null) {
      return const Center(
        child: Text(
          'Selecciona un trabajador',
          style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
        ),
      );
    }

    final msgs = chatDoc.collection('mensajes').orderBy('creadoEn');

    return _CardShell(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: const BoxDecoration(
              color: _card,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                if (mobileBack)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: _textDark),
                    onPressed: () => setState(() => _selected = null),
                  ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    (t.nombre.isNotEmpty ? t.nombre[0] : '?').toUpperCase(),
                    style: const TextStyle(color: _textDark, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: _textDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: msgs.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error en el chat:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Empieza la conversación 👇',
                      style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final text = (d['texto'] ?? '').toString();
                    final from = (d['enviadoPor'] ?? '').toString();
                    final isMe = from == myUid;

                    return _Bubble(
                      text: text,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),

          _ChatComposer(
            controller: _msgCtrl,
            hint: 'Escribe un mensaje…',
            onSend: _sendUserMessage,
          ),
        ],
      ),
    );
  }
}

// ============================
// ADMIN CHAT modern (single)
// ============================
class _AdminChatModern extends StatelessWidget {
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);

  final String empresaId;
  final String myUid;
  final DocumentReference<Map<String, dynamic>> chatDoc;
  final TextEditingController controller;
  final ScrollController scroll;
  final VoidCallback onSend;

  const _AdminChatModern({
    required this.empresaId,
    required this.myUid,
    required this.chatDoc,
    required this.controller,
    required this.scroll,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final msgs = chatDoc.collection('mensajes').orderBy('creadoEn');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: _CardShell(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                color: _card,
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                children: const [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.admin_panel_settings_outlined, size: 18, color: Color(0xFF2563EB)),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Administrador',
                      style: TextStyle(fontWeight: FontWeight.w900, color: _textDark),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: msgs.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Error en el chat:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Escribe al admin 👇',
                        style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i].data();
                      final text = (d['texto'] ?? '').toString();
                      final from = (d['enviadoPor'] ?? '').toString();
                      final isMe = from == myUid;

                      return _Bubble(text: text, isMe: isMe);
                    },
                  );
                },
              ),
            ),

            _ChatComposer(
              controller: controller,
              hint: 'Mensaje al admin…',
              onSend: onSend,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================
// Reusable UI pieces
// ============================
class _CardShell extends StatelessWidget {
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);

  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ChatComposer extends StatelessWidget {
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _soft = Color(0xFFF9FAFB);
  static const Color _blue = Color(0xFF2563EB);

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;

  const _ChatComposer({
    required this.controller,
    required this.hint,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  hintStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            height: 44,
            child: ElevatedButton(
              onPressed: onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: EdgeInsets.zero,
                elevation: 0,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  static const Color _me = Color(0xFF2563EB);
  static const Color _other = Color(0xFFF3F4F6);
  static const Color _textDark = Color(0xFF111827);

  final String text;
  final bool isMe;

  const _Bubble({
    required this.text,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? _me : _other;
    final fg = isMe ? Colors.white : _textDark;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(color: fg, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}