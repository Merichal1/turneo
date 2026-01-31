import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Tipos de mensaje
enum ChatMessageType { text, image }

String chatMessageTypeToString(ChatMessageType t) => t.name;

ChatMessageType chatMessageTypeFromString(String? v) {
  switch (v) {
    case 'image':
      return ChatMessageType.image;
    case 'text':
    default:
      return ChatMessageType.text;
  }
}

/// Servicio de chat V2 (multi-empresa)
/// empresas/{empresaId}/chats/{chatId}
/// empresas/{empresaId}/chats/{chatId}/messages/{messageId}
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  String get myUid => _auth.currentUser!.uid;

  // --------------------------
  // Helpers de rutas
  // --------------------------
  CollectionReference<Map<String, dynamic>> chatsRef(String empresaId) {
    return _db.collection('empresas').doc(empresaId).collection('chats');
  }

  DocumentReference<Map<String, dynamic>> chatDoc(String empresaId, String chatId) {
    return chatsRef(empresaId).doc(chatId);
  }

  CollectionReference<Map<String, dynamic>> messagesRef(String empresaId, String chatId) {
    return chatDoc(empresaId, chatId).collection('messages');
  }

  /// ✅ chatId determinista y estable (NO usar hashCode)
  String chatIdFor(String uidA, String uidB) {
    final pair = [uidA, uidB]..sort(); // orden estable cross-platform
    return '${pair[0]}_${pair[1]}';
  }

  // --------------------------
  // Push token
  // --------------------------
  Future<void> ensurePushTokenSaved(String empresaId) async {
    try {
      await _messaging.requestPermission();

      final token = await _messaging.getToken();
      if (token == null) return;

      final presRef = _db
          .collection('empresas')
          .doc(empresaId)
          .collection('presence')
          .doc(myUid);

      await presRef.set({
        'uid': myUid,
        'pushToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      log('ensurePushTokenSaved error: $e');
    }
  }

  Future<void> updatePresence(String empresaId, {required bool isOnline}) async {
    try {
      final presRef = _db
          .collection('empresas')
          .doc(empresaId)
          .collection('presence')
          .doc(myUid);

      await presRef.set({
        'uid': myUid,
        'isOnline': isOnline,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      log('updatePresence error: $e');
    }
  }

  // --------------------------
  // Streams
  // --------------------------

  /// ✅ Mensajes en tiempo real (orden inmediato por sentAtMs)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages({
    required String empresaId,
    required String chatId,
    int limit = 200,
  }) {
    return messagesRef(empresaId, chatId)
        .orderBy('sentAtMs', descending: false)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyChats({
    required String empresaId,
    int limit = 200,
  }) {
    return chatsRef(empresaId)
        .where('participants', arrayContains: myUid)
        .orderBy('lastMessageAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamLastMessage({
    required String empresaId,
    required String chatId,
  }) {
    return messagesRef(empresaId, chatId)
        .orderBy('sentAtMs', descending: true)
        .limit(1)
        .snapshots();
  }

  // --------------------------
  // Enviar mensajes
  // --------------------------

  Future<void> sendTextMessage({
    required String empresaId,
    required String toId,
    required String text,
    Map<String, dynamic>? chatMeta,
  }) async {
    final msg = text.trim();
    if (msg.isEmpty) return;

    final fromId = myUid;
    final cId = chatIdFor(fromId, toId);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final timeMs = nowMs.toString();

    final msgRef = messagesRef(empresaId, cId).doc(timeMs);

    final batch = _db.batch();

    batch.set(msgRef, {
      'id': timeMs,
      'fromId': fromId,
      'toId': toId,
      'type': 'text',
      'text': msg,
      'mediaUrl': '',
      'sentAt': FieldValue.serverTimestamp(),
      'sentAtMs': nowMs, // ✅
      'readAt': null,
      'editedAt': null,
      'deletedAt': null,
    });

    batch.set(
      chatDoc(empresaId, cId),
      {
        'chatId': cId,
        'participants': [fromId, toId],
        'lastMessage': msg,
        'lastMessageType': 'text',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageAtMs': nowMs, // ✅ opcional
        'lastSenderId': fromId,
        // ✅ createdAt solo si no existía (no se puede condicionar fácil en client)
        // pero con merge no pasa nada aunque se reescriba con serverTimestamp.
        'createdAt': FieldValue.serverTimestamp(),
        if (chatMeta != null) ...chatMeta,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> sendImageMessageFile({
    required String empresaId,
    required String toId,
    required File file,
    Map<String, dynamic>? chatMeta,
  }) async {
    final fromId = myUid;
    final cId = chatIdFor(fromId, toId);

    final ext = file.path.split('.').last.toLowerCase();
    final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storageRef = _storage.ref().child('empresas/$empresaId/chats/$cId/images/$name');

    await storageRef.putFile(file, SettableMetadata(contentType: 'image/$ext'));
    final url = await storageRef.getDownloadURL();

    await _sendImageUrlMessage(
      empresaId: empresaId,
      toId: toId,
      imageUrl: url,
      chatId: cId,
      chatMeta: chatMeta,
    );
  }

  Future<void> sendImageMessageBytes({
    required String empresaId,
    required String toId,
    required Uint8List bytes,
    required String ext,
    Map<String, dynamic>? chatMeta,
  }) async {
    final fromId = myUid;
    final cId = chatIdFor(fromId, toId);

    final safeExt = ext.toLowerCase().replaceAll('.', '');
    final name = '${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    final storageRef = _storage.ref().child('empresas/$empresaId/chats/$cId/images/$name');

    await storageRef.putData(bytes, SettableMetadata(contentType: 'image/$safeExt'));
    final url = await storageRef.getDownloadURL();

    await _sendImageUrlMessage(
      empresaId: empresaId,
      toId: toId,
      imageUrl: url,
      chatId: cId,
      chatMeta: chatMeta,
    );
  }

  Future<void> _sendImageUrlMessage({
    required String empresaId,
    required String toId,
    required String imageUrl,
    required String chatId,
    Map<String, dynamic>? chatMeta,
  }) async {
    final fromId = myUid;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final timeMs = nowMs.toString();

    final msgRef = messagesRef(empresaId, chatId).doc(timeMs);

    final batch = _db.batch();

    batch.set(msgRef, {
      'id': timeMs,
      'fromId': fromId,
      'toId': toId,
      'type': 'image',
      'text': '',
      'mediaUrl': imageUrl,
      'sentAt': FieldValue.serverTimestamp(),
      'sentAtMs': nowMs, // ✅
      'readAt': null,
      'editedAt': null,
      'deletedAt': null,
    });

    batch.set(
      chatDoc(empresaId, chatId),
      {
        'chatId': chatId,
        'participants': [fromId, toId],
        'lastMessage': '[imagen]',
        'lastMessageType': 'image',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageAtMs': nowMs,
        'lastSenderId': fromId,
        'createdAt': FieldValue.serverTimestamp(),
        if (chatMeta != null) ...chatMeta,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // --------------------------
  // Read / Edit / Delete
  // --------------------------

  Future<void> markMessageRead({
    required String empresaId,
    required String chatId,
    required String messageId,
    required String messageToId,
  }) async {
    if (messageToId != myUid) return;

    await messagesRef(empresaId, chatId).doc(messageId).update({
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMessageText({
    required String empresaId,
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    final txt = newText.trim();
    if (txt.isEmpty) return;

    await messagesRef(empresaId, chatId).doc(messageId).update({
      'text': txt,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage({
    required String empresaId,
    required String chatId,
    required String messageId,
    required ChatMessageType type,
    required String mediaUrl,
  }) async {
    await messagesRef(empresaId, chatId).doc(messageId).delete();

    if (type == ChatMessageType.image && mediaUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(mediaUrl).delete();
      } catch (e) {
        log('delete storage error: $e');
      }
    }
  }

  String myChatIdWith(String otherUid) => chatIdFor(myUid, otherUid);
}
