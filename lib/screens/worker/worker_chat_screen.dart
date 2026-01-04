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
  final String empresaId = AppConfig.empresaId;
  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  late final TabController _tab;

  // ---- Tab ADMIN ----
  final TextEditingController _adminMsgCtrl = TextEditingController();
  final ScrollController _adminScroll = ScrollController();

  // ---- Tab TRABAJADORES ----
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
        'creadoEn': FieldValue.serverTimestamp(),
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

    await Future.delayed(const Duration(milliseconds: 150));
    if (_adminScroll.hasClients) {
      _adminScroll.animateTo(
        _adminScroll.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // -------------------------
  // WORKERS CHAT (new)
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
        'creadoEn': FieldValue.serverTimestamp(),
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

    await Future.delayed(const Duration(milliseconds: 150));
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.admin_panel_settings_outlined), text: 'Admin'),
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Trabajadores'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildAdminChat(),
          isWide
              ? Row(
                  children: [
                    SizedBox(width: 360, child: _buildWorkersList()),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildWorkersChatPanel()),
                  ],
                )
              : (_selected == null
                  ? _buildWorkersList()
                  : _buildWorkersChatPanel(mobileBack: true)),
        ],
      ),
    );
  }

  // -------------------------
  // UI: ADMIN TAB
  // -------------------------
  Widget _buildAdminChat() {
    final msgs = _adminChatDoc.collection('mensajes').orderBy('creadoEn');

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: msgs.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Center(child: Text('Escribe al admin 👇'));
              }

              return ListView.builder(
                controller: _adminScroll,
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  final text = (d['texto'] ?? '').toString();
                  final from = (d['enviadoPor'] ?? '').toString();
                  final isMe = from == myUid;

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      constraints: const BoxConstraints(maxWidth: 520),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF6366F1) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _adminMsgCtrl,
                  decoration: InputDecoration(
                    hintText: 'Mensaje al admin…',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendAdminMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendAdminMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------
  // UI: WORKERS LIST
  // -------------------------
  Widget _buildWorkersList() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: 'Buscar trabajador...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _searchText = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<Trabajador>>(
              stream: FirestoreService.instance.listenTrabajadores(empresaId),
              builder: (context, snapshot) {
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
                  return const Center(child: Text('No hay resultados'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final t = filtered[i];
                    final selected = _selected?.id == t.id;

                    return ListTile(
                      selected: selected,
                      leading: CircleAvatar(
                        child: Text(
                          (t.nombre.isNotEmpty ? t.nombre[0] : '?').toUpperCase(),
                        ),
                      ),
                      title: Text(t.nombre),
                      onTap: () => setState(() => _selected = t),
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

  // -------------------------
  // UI: WORKERS CHAT PANEL
  // -------------------------
  Widget _buildWorkersChatPanel({bool mobileBack = false}) {
    final t = _selected;
    final chatDoc = _activeChatDoc;

    if (t == null || chatDoc == null) {
      return const Center(child: Text('Selecciona un trabajador'));
    }

    final msgs = chatDoc.collection('mensajes').orderBy('creadoEn');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              if (mobileBack)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _selected = null),
                ),
              CircleAvatar(
                child: Text((t.nombre.isNotEmpty ? t.nombre[0] : '?').toUpperCase()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: msgs.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Center(child: Text('Empieza la conversación 👇'));
              }

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  final text = (d['texto'] ?? '').toString();
                  final from = (d['enviadoPor'] ?? '').toString();
                  final isMe = from == myUid;

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      constraints: const BoxConstraints(maxWidth: 520),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF6366F1) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje…',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendUserMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendUserMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
