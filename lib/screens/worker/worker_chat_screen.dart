import 'package:flutter/material.dart';

class WorkerChatScreen extends StatefulWidget {
  const WorkerChatScreen({super.key});

  @override
  State<WorkerChatScreen> createState() => _WorkerChatScreenState();
}

class _WorkerChatScreenState extends State<WorkerChatScreen> {
  int _selectedIndex = 0;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Conversaciones simuladas.
  /// type puede ser: 'admin', 'coordinator', 'worker'
  final List<Map<String, dynamic>> _conversations = [
    {
      "name": "Carlos Admin",
      "type": "admin",
      "subtitle": "Administrador",
      "last": "Perfecto, estaré allí a las 19:00",
      "time": "Hace 5 min",
      "unread": 0,
      "messages": [
        {
          "text": "Hola, ¿a qué hora comienza el evento del sábado?",
          "time": "10:30",
          "me": false, // admin
        },
        {
          "text":
              "Hola, el evento comienza a las 19:00. La concentración es a las 18:30.",
          "time": "10:32",
          "me": true, // trabajador
        },
        {
          "text": "¿Dónde es exactamente?",
          "time": "10:35",
          "me": false,
        },
        {
          "text":
              "Hotel Ritz, Calle Felipe IV, 5. Te enviamos la ubicación exacta por email.",
          "time": "10:36",
          "me": true,
        },
        {
          "text": "Perfecto, estaré allí a las 19:00",
          "time": "10:40",
          "me": false,
        },
      ],
    },
    {
      "name": "Ana Martínez",
      "type": "coordinator",
      "subtitle": "Coordinadora del evento",
      "last": "Recuerda llevar camisa blanca 🙂",
      "time": "Hace 1 h",
      "unread": 1,
      "messages": [
        {
          "text": "¿Qué uniforme debo llevar exactamente?",
          "time": "11:00",
          "me": true,
        },
        {
          "text":
              "Camisa blanca, pantalón negro y zapatos negros. Nosotros ponemos chaleco y pajarita.",
          "time": "11:05",
          "me": false,
        },
        {
          "text": "Perfecto, gracias!",
          "time": "11:07",
          "me": true,
        },
        {
          "text": "Recuerda llevar camisa blanca 🙂",
          "time": "11:15",
          "me": false,
        },
      ],
    },
    {
      "name": "María García",
      "type": "worker",
      "subtitle": "Compañera · Camarera",
      "last": "Nos vemos allí 30 min antes",
      "time": "Ayer",
      "unread": 0,
      "messages": [
        {
          "text": "¿Vas al evento del sábado también?",
          "time": "18:20",
          "me": true,
        },
        {
          "text": "Sí, estaré en barra. ¿Tú en sala?",
          "time": "18:22",
          "me": false,
        },
        {
          "text": "Eso es, nos vemos allí 30 min antes 🙂",
          "time": "18:25",
          "me": true,
        },
      ],
    },
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _currentConversation =>
      _conversations[_selectedIndex];

  // Helpers seguros para strings / ints
  String _s(dynamic v) => v?.toString() ?? '';
  int _i(dynamic v) => (v is int) ? v : 0;

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _currentConversation["messages"].add({
        "text": text,
        "time": _nowTimeString(),
        "me": true,
      });
      _controller.clear();
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _nowTimeString() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'admin':
        return 'Admin';
      case 'coordinator':
        return 'Coordinador';
      case 'worker':
        return 'Compañero';
      default:
        return '';
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'admin':
        return const Color(0xFF111827);
      case 'coordinator':
        return const Color(0xFF2563EB);
      case 'worker':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conv = _currentConversation;
    final name = _s(conv["name"]);
    final subtitle = _s(conv["subtitle"]);
    final type = _s(conv["type"]);

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CABECERA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Mensajes',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Chatea con administradores, coordinadores y compañeros',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),

            // LISTA DE CONVERSACIONES (HORIZONTAL)
            SizedBox(
              height: 110,
              child: ListView.separated(
                padding: const EdgeInsets.only(left: 16, right: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _conversations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final c = _conversations[index];
                  final bool selected = index == _selectedIndex;

                  final cName = _s(c["name"]);
                  final cSubtitle = _s(c["subtitle"]);
                  final cLast = _s(c["last"]);
                  final cTime = _s(c["time"]);
                  final cType = _s(c["type"]);
                  final unread = _i(c["unread"]);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                        c["unread"] = 0;
                      });
                    },
                    child: Container(
                      width: 210,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            selected ? Colors.white : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF111827)
                              : const Color(0xFFE5E7EB),
                          width: selected ? 1 : 0.8,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                  color: Colors.black.withOpacity(0.08),
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      _typeColor(cType).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _typeLabel(cType),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _typeColor(cType),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  cSubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cLast,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                cTime,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFA1A1AA),
                                ),
                              ),
                              const Spacer(),
                              if (unread > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111827),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
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
              ),
            ),

            const SizedBox(height: 8),

            // HEADER CONVERSACIÓN ACTUAL
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _typeColor(type).withOpacity(0.15),
                    child: Text(
                      name.isNotEmpty ? name[0] : '?',
                      style: TextStyle(
                        color: _typeColor(type),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _typeColor(type).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _typeLabel(type),
                      style: TextStyle(
                        fontSize: 11,
                        color: _typeColor(type),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),
            const Divider(height: 1),

            // MENSAJES
            Expanded(
              child: Container(
                color: const Color(0xFFF3F4F6),
                child: ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: (conv["messages"] as List).length,
                  itemBuilder: (context, index) {
                    final msg = conv["messages"][index];
                    final bool me = msg["me"] == true;
                    final text = _s(msg["text"]);
                    final time = _s(msg["time"]);

                    return Align(
                      alignment:
                          me ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: me
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: me
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              text,
                              style: TextStyle(
                                fontSize: 14,
                                color: me ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    me ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // INPUT
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.send,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
