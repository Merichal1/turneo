import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ClipboardData, Clipboard;

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/trabajador.dart';

class WorkerChatScreen extends StatefulWidget {
  const WorkerChatScreen({super.key});

  @override
  State<WorkerChatScreen> createState() => _WorkerChatScreenState();
}

class _WorkerChatScreenState extends State<WorkerChatScreen> with SingleTickerProviderStateMixin {
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

  // ---- ADMIN CHAT ----
  final TextEditingController _adminMsgCtrl = TextEditingController();
  final ScrollController _adminScroll = ScrollController();

  // ---- WORKERS CHAT ----
  Trabajador? _selected;
  String _searchText = '';
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // ✅ cache local para no recalcular siempre
  final Map<String, String> _photoUrlCache = <String, String>{};

  // ✅ cache admins (para mostrar qué admin escribe)
  final Map<String, Map<String, String>> _adminCache = <String, Map<String, String>>{};
  final Map<String, Future<void>> _adminInflight = <String, Future<void>>{};

  // ✅ edición (admin chat)
  String? _editingAdminMsgId;
  bool get _isEditingAdmin => _editingAdminMsgId != null;

  // ✅ edición (workers chat)
  String? _editingUserMsgId;
  bool get _isEditingUser => _editingUserMsgId != null;

  // Workers chat collection
  CollectionReference<Map<String, dynamic>> get _userChats =>
      FirebaseFirestore.instance.collection('empresas').doc(empresaId).collection('chats_usuarios');

  // Admin chat doc (el chat ENTRE este trabajador y admins)
  DocumentReference<Map<String, dynamic>> get _adminChatDoc =>
      FirebaseFirestore.instance.collection('empresas').doc(empresaId).collection('chats_trabajadores').doc(myUid);

  String _chatIdFor(String a, String b) {
    final pair = [a, b]..sort();
    return '${pair[0]}_${pair[1]}';
  }

  DocumentReference<Map<String, dynamic>>? get _activeChatDoc {
    final other = _selected?.id;
    if (other == null) return null;
    return _userChats.doc(_chatIdFor(myUid, other));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _workerDocStream(String uid) {
    return FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('trabajadores')
        .doc(uid)
        .snapshots();
  }

  // =========================
  // ADMIN PROFILE RESOLVE
  // =========================
  DocumentReference<Map<String, dynamic>> _adminDocRef(String adminUid) {
    // Tu estructura: empresas/{empresaId}/Administradores/{adminUid}
    return FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('Administradores')
        .doc(adminUid);
  }

  String _extractAdminName(Map<String, dynamic>? data, {required String fallbackUid}) {
    if (data == null) return 'Admin';
    final perfil = (data['perfil'] is Map) ? Map<String, dynamic>.from(data['perfil']) : <String, dynamic>{};
    final nombre = ((data['nombre'] ?? perfil['nombre']) ?? '').toString().trim();
    final apellidos = ((data['apellidos'] ?? perfil['apellidos']) ?? '').toString().trim();
    final full = ('$nombre $apellidos').trim();
    if (full.isNotEmpty) return full;
    final dn = (data['displayName'] ?? data['name'] ?? '').toString().trim();
    if (dn.isNotEmpty) return dn;
    return 'Admin';
  }

  String _extractAdminPhoto(Map<String, dynamic>? data) {
    if (data == null) return '';
    String readString(dynamic v) => (v ?? '').toString().trim();
    final perfil = (data['perfil'] is Map) ? Map<String, dynamic>.from(data['perfil']) : <String, dynamic>{};
    final root = readString(data['photoUrl']);
    final perfilUrl = readString(perfil['photoUrl']);
    return root.isNotEmpty ? root : perfilUrl;
  }

  Future<void> _ensureAdminCached(String adminUid) async {
    if (adminUid.isEmpty) return;
    if (_adminCache.containsKey(adminUid)) return;
    if (_adminInflight.containsKey(adminUid)) return _adminInflight[adminUid]!;

    final f = () async {
      try {
        final snap = await _adminDocRef(adminUid).get();
        final data = snap.data();
        _adminCache[adminUid] = {
          'name': _extractAdminName(data, fallbackUid: adminUid),
          'photoUrl': _extractAdminPhoto(data),
        };
        if (mounted) setState(() {});
      } catch (_) {
        _adminCache[adminUid] = {'name': 'Admin', 'photoUrl': ''};
      } finally {
        _adminInflight.remove(adminUid);
      }
    }();

    _adminInflight[adminUid] = f;
    return f;
  }

  String _adminName(String adminUid) => (_adminCache[adminUid] ?? const {})['name'] ?? 'Admin';
  String _adminPhoto(String adminUid) => (_adminCache[adminUid] ?? const {})['photoUrl'] ?? '';

  Future<List<String>> _fetchAdminUids() async {
    final snap = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('Administradores')
        .get();

    final uids = <String>[];
    for (final d in snap.docs) {
      final data = d.data();
      final estado = (data['Estado'] ?? data['estado'] ?? '').toString().trim().toLowerCase();
      if (estado.isEmpty || estado == 'activo') {
        uids.add(d.id);
      }
    }
    return uids;
  }

  Stream<int> _adminUnreadCountStream() {
    return _adminChatDoc.snapshots().map((snap) {
      final data = snap.data() ?? {};
      final unread = (data['unread'] is Map) ? Map<String, dynamic>.from(data['unread']) : <String, dynamic>{};
      final v = unread[myUid];
      return (v is num) ? v.toInt() : 0;
    });
  }

  Stream<int> _workersUnreadTotalStream() {
    return _userChats.where('members', arrayContains: myUid).snapshots().map((q) {
      int total = 0;
      for (final d in q.docs) {
        final data = d.data();
        final unread = (data['unread'] is Map) ? Map<String, dynamic>.from(data['unread']) : <String, dynamic>{};
        final v = unread[myUid];
        total += (v is num) ? v.toInt() : 0;
      }
      return total;
    });
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);

    _tab.addListener(() async {
      if (_tab.indexIsChanging) return;

      // Tab Admin: marco leído miUid + guardo lastReadAt del worker (para que el admin luego tenga ticks)
      if (_tab.index == 0) {
        await _adminChatDoc.set({
          'unread.$myUid': 0,
          'lastReadAt.$myUid': FieldValue.serverTimestamp(), // ✅ worker leyó
        }, SetOptions(merge: true));
      }

      // Tab Trabajadores: si hay chat abierto, marco leído
      if (_tab.index == 1 && _selected != null) {
        final chatDoc = _activeChatDoc;
        if (chatDoc != null) {
          await chatDoc.set({'unread.$myUid': 0}, SetOptions(merge: true));
        }
      }
    });

    // ✅ Al entrar: admin chat leído
    unawaited(_adminChatDoc.set({
      'unread.$myUid': 0,
      'lastReadAt.$myUid': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));
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

  // ==========================
  // EDIT / DELETE helpers
  // ==========================
  Future<void> _updateMessageText({
    required DocumentReference<Map<String, dynamic>> chatDoc,
    required String msgId,
    required String newText,
  }) async {
    final t = newText.trim();
    if (t.isEmpty) return;

    await chatDoc.collection('mensajes').doc(msgId).set({
      'texto': t,
      'editado': true,
      'editadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // (simple) mantener último mensaje si era mío
    final chatSnap = await chatDoc.get();
    final chatData = chatSnap.data() ?? {};
    final ultimoPor = (chatData['ultimoMensajePor'] ?? '').toString();

    if (ultimoPor == myUid) {
      await chatDoc.set({
        'ultimoMensaje': t,
        'ultimoMensajeEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _deleteMessage({
    required DocumentReference<Map<String, dynamic>> chatDoc,
    required String msgId,
  }) async {
    await chatDoc.collection('mensajes').doc(msgId).delete();
  }

  // -------------------------
  // ADMIN CHAT (trabajador <-> admins)
  // -------------------------
  Future<void> _sendAdminMessage() async {
    final raw = _adminMsgCtrl.text;
    final text = raw.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final msgs = _adminChatDoc.collection('mensajes');

    // ✅ si estoy editando, actualizo
    if (_editingAdminMsgId != null) {
      final msgId = _editingAdminMsgId!;
      _adminMsgCtrl.clear();
      setState(() => _editingAdminMsgId = null);
      await _updateMessageText(chatDoc: _adminChatDoc, msgId: msgId, newText: text);
      return;
    }

    _adminMsgCtrl.clear();

    final batch = FirebaseFirestore.instance.batch();
    final msgRef = msgs.doc();

    batch.set(
      msgRef,
      {
        'id': msgRef.id,
        'texto': text,
        'enviadoPor': myUid,
        'enviadoEn': Timestamp.fromDate(now),
        'creadoEn': Timestamp.fromDate(now),
        'editado': false,
      },
    );

    // ✅ MULTI-ADMIN: incrementa a TODOS los admins
    final adminUids = await _fetchAdminUids();

    final updates = <String, dynamic>{
      'trabajadorId': myUid,
      'ultimoMensaje': text,
      'ultimoMensajePor': myUid,
      'ultimoMensajeEn': Timestamp.fromDate(now),
      'creadoEn': FieldValue.serverTimestamp(),
      'unread.$myUid': 0,
      // ✅ como acabo de enviar, yo “no necesito” marcar leído, pero dejo mi lastReadAt actualizado:
      'lastReadAt.$myUid': FieldValue.serverTimestamp(),
    };

    for (final adminUid in adminUids) {
      updates['unread.$adminUid'] = FieldValue.increment(1);
      unawaited(_ensureAdminCached(adminUid));
    }

    batch.set(_adminChatDoc, updates, SetOptions(merge: true));
    await batch.commit();

    await Future.delayed(const Duration(milliseconds: 120));
    if (_adminScroll.hasClients) {
      _adminScroll.animateTo(
        0,
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

    final raw = _msgCtrl.text;
    final text = raw.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final msgs = chatDoc.collection('mensajes');

    // ✅ si estoy editando, actualizo
    if (_editingUserMsgId != null) {
      final msgId = _editingUserMsgId!;
      _msgCtrl.clear();
      setState(() => _editingUserMsgId = null);
      await _updateMessageText(chatDoc: chatDoc, msgId: msgId, newText: text);
      return;
    }

    _msgCtrl.clear();

    final batch = FirebaseFirestore.instance.batch();
    final msgRef = msgs.doc();

    batch.set(
      msgRef,
      {
        'id': msgRef.id,
        'texto': text,
        'enviadoPor': myUid,
        'enviadoEn': Timestamp.fromDate(now),
        'creadoEn': Timestamp.fromDate(now),
        'editado': false,
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
        'unread.${other.id}': FieldValue.increment(1),
        'unread.$myUid': 0,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    await Future.delayed(const Duration(milliseconds: 120));
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // ==========================
  // UI
  // ==========================
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
                tabs: [
                  StreamBuilder<int>(
                    stream: _adminUnreadCountStream(),
                    builder: (_, snap) {
                      final count = snap.data ?? 0;
                      return _BadgeTab(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Admin',
                        count: count,
                      );
                    },
                  ),
                  StreamBuilder<int>(
                    stream: _workersUnreadTotalStream(),
                    builder: (_, snap) {
                      final count = snap.data ?? 0;
                      return _BadgeTab(
                        icon: Icons.people_alt_outlined,
                        label: 'Trabajadores',
                        count: count,
                      );
                    },
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
          _AdminChatModern(
            empresaId: empresaId,
            myUid: myUid,
            chatDoc: _adminChatDoc,
            controller: _adminMsgCtrl,
            scroll: _adminScroll,
            onSend: _sendAdminMessage,
            myWorkerDocStream: _workerDocStream(myUid),

            ensureAdminCached: _ensureAdminCached,
            adminName: _adminName,
            adminPhoto: _adminPhoto,

            onEdit: (msgId, currentText) {
              setState(() => _editingAdminMsgId = msgId);
              _adminMsgCtrl.text = currentText;
              _adminMsgCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _adminMsgCtrl.text.length));
            },
            onDelete: (msgId) => _deleteMessage(chatDoc: _adminChatDoc, msgId: msgId),
            isEditing: _isEditingAdmin,
            onCancelEdit: () {
              setState(() => _editingAdminMsgId = null);
              _adminMsgCtrl.clear();
            },
          ),

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
                  child: (_selected == null) ? _WorkersListModern() : _WorkersChatModern(mobileBack: true),
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
                  final full = ('${t.nombre ?? ''} ${t.apellidos ?? ''}').toLowerCase();
                  return full.contains(_searchText);
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
                    final name = ('${t.nombre ?? ''} ${t.apellidos ?? ''}').trim();
                    final initials = _initials(t.nombre ?? '', t.apellidos ?? '');

                    final chatDoc = _userChats.doc(_chatIdFor(myUid, t.id));

                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: chatDoc.snapshots(),
                      builder: (context, chatSnap) {
                        int unread = 0;
                        if (chatSnap.hasData && chatSnap.data!.exists) {
                          final data = chatSnap.data!.data() ?? {};
                          final map = (data['unread'] is Map) ? Map<String, dynamic>.from(data['unread']) : {};
                          final v = map[myUid];
                          unread = (v is num) ? v.toInt() : 0;
                        }

                        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: _workerDocStream(t.id),
                          builder: (context, workerSnap) {
                            final photoUrl = _extractPhotoUrl(workerSnap.data?.data());
                            if (photoUrl.trim().isNotEmpty) _photoUrlCache[t.id] = photoUrl.trim();
                            final effectiveUrl = (_photoUrlCache[t.id] ?? photoUrl).trim();

                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                setState(() => _selected = t);
                                await chatDoc.set({'unread.$myUid': 0}, SetOptions(merge: true));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected ? const Color(0xFFEFF6FF) : _soft,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected ? const Color(0xFFC7D2FE) : _border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _WorkerAvatar(
                                      photoUrl: effectiveUrl,
                                      initials: initials,
                                      radius: 18,
                                      bgSelected: selected,
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
                                    if (unread > 0) ...[
                                      const SizedBox(width: 8),
                                      _Badge(count: unread),
                                    ],
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                                  ],
                                ),
                              ),
                            );
                          },
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

    final msgs = chatDoc.collection('mensajes').orderBy('creadoEn', descending: true);

    return _CardShell(
      child: Column(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _workerDocStream(t.id),
            builder: (context, snap) {
              final photoUrl = _extractPhotoUrl(snap.data?.data());
              if (photoUrl.trim().isNotEmpty) _photoUrlCache[t.id] = photoUrl.trim();
              final effective = (_photoUrlCache[t.id] ?? photoUrl).trim();
              final initials = _initials(t.nombre ?? '', t.apellidos ?? '');

              return Container(
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
                    _WorkerAvatar(
                      photoUrl: effective,
                      initials: initials,
                      radius: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ('${t.nombre ?? ''} ${t.apellidos ?? ''}').trim(),
                        style: const TextStyle(fontWeight: FontWeight.w900, color: _textDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isEditingUser)
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _editingUserMsgId = null);
                          _msgCtrl.clear();
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: msgs.snapshots(includeMetadataChanges: true),
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

                unawaited(chatDoc.set({'unread.$myUid': 0}, SetOptions(merge: true)));

                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final text = (d['texto'] ?? '').toString();
                    final from = (d['enviadoPor'] ?? '').toString();
                    final isMe = from == myUid;
                    final edited = (d['editado'] == true);

                    final ts = (d['creadoEn'] as Timestamp?) ?? (d['enviadoEn'] as Timestamp?);
                    final timeText = _formatHHmm(ts);

                    return _Bubble(
                      text: text,
                      isMe: isMe,
                      subtitle: edited ? 'Editado' : null,
                      timeText: timeText,
                      onLongPress: () => _openMsgActions(
                        context: context,
                        isMe: isMe,
                        currentText: text,
                        onEdit: () {
                          Navigator.pop(context);
                          setState(() => _editingUserMsgId = doc.id);
                          _msgCtrl.text = text;
                          _msgCtrl.selection =
                              TextSelection.fromPosition(TextPosition(offset: _msgCtrl.text.length));
                        },
                        onDelete: () async {
                          Navigator.pop(context);
                          await _deleteMessage(chatDoc: chatDoc, msgId: doc.id);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _ChatComposer(
            controller: _msgCtrl,
            hint: _isEditingUser ? 'Editar mensaje…' : 'Escribe un mensaje…',
            onSend: _sendUserMessage,
            onPickEmoji: () => _openEmojiPicker(
              context: context,
              onEmoji: (e) => _insertEmoji(_msgCtrl, e),
            ),
          ),
        ],
      ),
    );
  }

  void _insertEmoji(TextEditingController ctrl, String emoji) {
    final value = ctrl.value;
    final start = value.selection.start;
    final end = value.selection.end;
    final text = value.text;

    if (start < 0 || end < 0) {
      ctrl.text = text + emoji;
      ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
      return;
    }

    final newText = text.replaceRange(start, end, emoji);
    ctrl.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
      composing: TextRange.empty,
    );
  }

  void _openEmojiPicker({
    required BuildContext context,
    required ValueChanged<String> onEmoji,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EmojiSheet(onEmoji: (e) {
        onEmoji(e);
        Navigator.pop(context);
      }),
    );
  }

  void _openMsgActions({
    required BuildContext context,
    required bool isMe,
    required String currentText,
    required VoidCallback onEdit,
    required Future<void> Function() onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined),
                  title: const Text('Copiar'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: currentText));
                    Navigator.pop(context);
                  },
                ),
                if (isMe) ...[
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Editar'),
                    onTap: onEdit,
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('Borrar', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      await onDelete();
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================
// ADMIN CHAT modern (single)
// ============================
class _AdminChatModern extends StatelessWidget {
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
  final Stream<DocumentSnapshot<Map<String, dynamic>>> myWorkerDocStream;

  // ✅ admin resolve
  final Future<void> Function(String adminUid) ensureAdminCached;
  final String Function(String adminUid) adminName;
  final String Function(String adminUid) adminPhoto;

  // ✅ edit/delete
  final void Function(String msgId, String currentText) onEdit;
  final Future<void> Function(String msgId) onDelete;
  final bool isEditing;
  final VoidCallback onCancelEdit;

  const _AdminChatModern({
    required this.empresaId,
    required this.myUid,
    required this.chatDoc,
    required this.controller,
    required this.scroll,
    required this.onSend,
    required this.myWorkerDocStream,
    required this.ensureAdminCached,
    required this.adminName,
    required this.adminPhoto,
    required this.onEdit,
    required this.onDelete,
    required this.isEditing,
    required this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context) {
    final msgs = chatDoc.collection('mensajes').orderBy('creadoEn', descending: true);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: _CardShell(
        child: Column(
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: myWorkerDocStream,
              builder: (context, snap) {
                final photoUrl = _extractPhotoUrl(snap.data?.data());
                final initials = _initialsFromMap(snap.data?.data());

                return Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: const BoxDecoration(
                    color: _card,
                    border: Border(bottom: BorderSide(color: _border)),
                  ),
                  child: Row(
                    children: [
                      _WorkerAvatar(
                        photoUrl: photoUrl,
                        initials: initials,
                        radius: 18,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Administración',
                          style: TextStyle(fontWeight: FontWeight.w900, color: _textDark),
                        ),
                      ),
                      if (isEditing)
                        TextButton.icon(
                          onPressed: onCancelEdit,
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                );
              },
            ),

            // ✅ NECESITAMOS chatDoc snapshot para calcular ticks (admins lastReadAt)
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: chatDoc.snapshots(),
                builder: (context, chatSnap) {
                  final chatData = chatSnap.data?.data() ?? {};
                  final lastReadAtMap = (chatData['lastReadAt'] is Map)
                      ? Map<String, dynamic>.from(chatData['lastReadAt'])
                      : <String, dynamic>{};

                  // ✅ max lastReadAt de admins (todos menos myUid)
                  Timestamp? maxAdminRead;
                  lastReadAtMap.forEach((uid, v) {
                    if (uid == myUid) return;
                    final ts = (v is Timestamp) ? v : null;
                    if (ts == null) return;
                    if (maxAdminRead == null) {
                      maxAdminRead = ts;
                    } else {
                      if (ts.toDate().isAfter(maxAdminRead!.toDate())) maxAdminRead = ts;
                    }
                  });

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

                      // ✅ cuando ves el chat admin, lo marcas leído + lastReadAt worker
                      unawaited(chatDoc.set({
                        'unread.$myUid': 0,
                        'lastReadAt.$myUid': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true)));

                      return ListView.builder(
                        controller: scroll,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          final d = doc.data();
                          final text = (d['texto'] ?? '').toString();
                          final from = (d['enviadoPor'] ?? '').toString();
                          final isMe = from == myUid;
                          final edited = (d['editado'] == true);

                          final ts = (d['creadoEn'] as Timestamp?) ?? (d['enviadoEn'] as Timestamp?);
                          final timeText = _formatHHmm(ts);

                          // ✅ TICKS: solo para mensajes míos (worker -> admin)
                          bool seenByAdmin = false;
                          if (isMe && ts != null && maxAdminRead != null) {
                            // si algún admin leyó DESPUÉS de que yo lo envié => visto
                            seenByAdmin = !maxAdminRead!.toDate().isBefore(ts.toDate());
                          }

                          // ✅ si viene de un admin, precacheamos y mostramos quién
                          String? senderLabel;
                          String senderPhoto = '';
                          if (!isMe && from.isNotEmpty) {
                            ensureAdminCached(from);
                            senderLabel = adminName(from);
                            senderPhoto = adminPhoto(from);
                          }

                          return _Bubble(
                            text: text,
                            isMe: isMe,
                            subtitle: edited ? 'Editado' : null,
                            timeText: timeText,
                            showTicks: isMe,       // ✅ solo para mis mensajes en admin chat
                            ticksSeen: seenByAdmin, // ✅ azul si visto
                            senderName: (!isMe) ? senderLabel : null,
                            senderPhotoUrl: (!isMe) ? senderPhoto : null,
                            onLongPress: () => _openMsgActionsAdmin(
                              context: context,
                              isMe: isMe,
                              currentText: text,
                              onEditTap: () {
                                Navigator.pop(context);
                                onEdit(doc.id, text);
                              },
                              onDeleteTap: () async {
                                Navigator.pop(context);
                                await onDelete(doc.id);
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            _ChatComposer(
              controller: controller,
              hint: isEditing ? 'Editar mensaje…' : 'Mensaje al admin…',
              onSend: onSend,
              onPickEmoji: () => _openEmojiPickerAdmin(
                context: context,
                onEmoji: (e) => _insertEmojiAdmin(controller, e),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _insertEmojiAdmin(TextEditingController ctrl, String emoji) {
    final value = ctrl.value;
    final start = value.selection.start;
    final end = value.selection.end;
    final text = value.text;

    if (start < 0 || end < 0) {
      ctrl.text = text + emoji;
      ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
      return;
    }

    final newText = text.replaceRange(start, end, emoji);
    ctrl.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
      composing: TextRange.empty,
    );
  }

  void _openEmojiPickerAdmin({
    required BuildContext context,
    required ValueChanged<String> onEmoji,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EmojiSheet(onEmoji: (e) {
        onEmoji(e);
        Navigator.pop(context);
      }),
    );
  }

  void _openMsgActionsAdmin({
    required BuildContext context,
    required bool isMe,
    required String currentText,
    required VoidCallback onEditTap,
    required Future<void> Function() onDeleteTap,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined),
                  title: const Text('Copiar'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: currentText));
                    Navigator.pop(context);
                  },
                ),
                if (isMe) ...[
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Editar'),
                    onTap: onEditTap,
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('Borrar', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      await onDeleteTap();
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
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
  final VoidCallback onPickEmoji;

  const _ChatComposer({
    required this.controller,
    required this.hint,
    required this.onSend,
    required this.onPickEmoji,
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
          IconButton(
            onPressed: onPickEmoji,
            icon: const Icon(Icons.emoji_emotions_outlined),
            color: const Color(0xFF64748B),
          ),
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

  // ✅ extra
  final String? subtitle;      // ej: "Editado"
  final String? timeText;      // HH:mm
  final bool showTicks;        // mostrar ticks en el footer (solo mis mensajes)
  final bool ticksSeen;        // azul si leído

  final String? senderName;    // para admin que escribe
  final String? senderPhotoUrl;
  final VoidCallback? onLongPress;

  const _Bubble({
    required this.text,
    required this.isMe,
    this.subtitle,
    this.timeText,
    this.showTicks = false,
    this.ticksSeen = false,
    this.senderName,
    this.senderPhotoUrl,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? _me : _other;
    final fg = isMe ? Colors.white : _textDark;

    final hasSender = !isMe && (senderName ?? '').trim().isNotEmpty;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
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
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (hasSender) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TinyAvatar(url: senderPhotoUrl ?? ''),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        senderName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : const Color(0xFF334155),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                text,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600),
              ),

              // ✅ footer: (Editado) + hora + ticks
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if ((subtitle ?? '').isNotEmpty)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if ((subtitle ?? '').isNotEmpty && (timeText ?? '').isNotEmpty) const SizedBox(width: 8),
                  if ((timeText ?? '').isNotEmpty)
                    Text(
                      timeText!,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (showTicks) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.done_all,
                      size: 16,
                      color: ticksSeen ? const Color(0xFF60A5FA) : (isMe ? Colors.white70 : Colors.black45),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyAvatar extends StatelessWidget {
  final String url;
  const _TinyAvatar({required this.url});

  @override
  Widget build(BuildContext context) {
    final has = url.trim().isNotEmpty;
    return CircleAvatar(
      radius: 10,
      backgroundColor: const Color(0xFFEFF6FF),
      child: ClipOval(
        child: SizedBox(
          width: 20,
          height: 20,
          child: has
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 14, color: Color(0xFF2563EB)),
                )
              : const Icon(Icons.person, size: 14, color: Color(0xFF2563EB)),
        ),
      ),
    );
  }
}

// ============================
// TAB con badge
// ============================
class _BadgeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _BadgeTab({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final show = count > 0;
    final text = count > 99 ? '99+' : count.toString();

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 18),
              if (show)
                Positioned(
                  right: -10,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

// ============================
// AVATAR + BADGE + HELPERS
// ============================
class _WorkerAvatar extends StatelessWidget {
  final String photoUrl;
  final String initials;
  final double radius;
  final bool bgSelected;

  const _WorkerAvatar({
    required this.photoUrl,
    required this.initials,
    required this.radius,
    this.bgSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.trim().isNotEmpty;
    final size = radius * 2;

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgSelected ? const Color(0xFFDBEAFE) : const Color(0xFFEFF6FF),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: hasPhoto
              ? Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _InitialsAvatar(initials: initials.isEmpty ? '?' : initials),
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                )
              : _InitialsAvatar(initials: initials.isEmpty ? '?' : initials),
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFF6FF),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}

class _EmojiSheet extends StatelessWidget {
  final ValueChanged<String> onEmoji;
  const _EmojiSheet({required this.onEmoji});

  static const _emojis = <String>[
    "😀","😄","😁","😂","🤣","🙂","😉","😍","😘","😎","🤝","🙏",
    "👍","👎","👏","💪","🔥","✨","🎉","✅","❌","⚠️","📌","🕒",
    "❤️","🧡","💛","💚","💙","💜","🤍","🖤","💬","📎","📍","🫡",
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Emojis',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _emojis.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (_, i) {
                final e = _emojis[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onEmoji(e),
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// HELPERS
// ======================================================
String _initials(String nombre, String apellidos) {
  final n = nombre.trim();
  final a = apellidos.trim();
  if (n.isEmpty && a.isEmpty) return '?';
  final first = n.isNotEmpty ? n[0].toUpperCase() : '?';
  final second = a.isNotEmpty ? a[0].toUpperCase() : '';
  return '$first$second';
}

String _initialsFromMap(Map<String, dynamic>? data) {
  if (data == null) return '?';
  final perfil = (data['perfil'] is Map) ? Map<String, dynamic>.from(data['perfil']) : <String, dynamic>{};
  final nombre = ((data['nombre'] ?? perfil['nombre']) ?? '').toString();
  final apellidos = ((data['apellidos'] ?? perfil['apellidos']) ?? '').toString();
  return _initials(nombre, apellidos);
}

String _extractPhotoUrl(Map<String, dynamic>? data) {
  if (data == null) return '';
  String readString(dynamic v) => (v ?? '').toString().trim();

  final perfil = (data['perfil'] is Map) ? Map<String, dynamic>.from(data['perfil']) : <String, dynamic>{};

  final photoUrlRoot = readString(data['photoUrl']);
  final photoUrlPerfil = readString(perfil['photoUrl']);

  return photoUrlRoot.isNotEmpty ? photoUrlRoot : photoUrlPerfil;
}

String _formatHHmm(Timestamp? ts) {
  if (ts == null) return '';
  final dt = ts.toDate();
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
