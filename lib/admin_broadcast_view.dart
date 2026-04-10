import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

class BroadcastMessageView extends StatefulWidget {
  const BroadcastMessageView({super.key});

  @override
  State<BroadcastMessageView> createState() => _BroadcastMessageViewState();
}

class _BroadcastMessageViewState extends State<BroadcastMessageView> {
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  final _messageController = TextEditingController();
  bool _isSending = false;

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await _database.child('group_chat').push().set({
        'senderId': _auth.currentUser?.uid ?? 'admin',
        'senderName': 'ADMIN',
        'text': text,
        'isAdmin': true,
        'timestamp': ServerValue.timestamp,
      });
      _messageController.clear();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('COUNCIL BROADCAST')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _database.child('group_chat').orderByChild('timestamp').limitToLast(100).onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) return const Center(child: Text('Voice of the owner is silent.', style: TextStyle(color: Colors.white24)));

                final Map<dynamic, dynamic> chatMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final messages = chatMap.values.map((v) => Map<String, dynamic>.from(v as Map)).toList();
                messages.sort((a, b) => (a['timestamp'] as int? ?? 0).compareTo(b['timestamp'] as int? ?? 0));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isAdmin = msg['isAdmin'] == true;
                    final date = DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] as int? ?? 0);
                    final timeStr = DateFormat('hh:mm a').format(date);

                    return FadeInUp(
                      duration: const Duration(milliseconds: 300),
                      child: Align(
                        alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isAdmin ? Theme.of(context).primaryColor : const Color(0xFF161B22),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isAdmin ? 20 : 0),
                              bottomRight: Radius.circular(isAdmin ? 0 : 20),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isAdmin) Text(msg['senderName'] ?? '', style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(msg['text'] ?? '', style: TextStyle(color: isAdmin ? Colors.black : Colors.white, fontSize: 15)),
                              const SizedBox(height: 4),
                              Align(alignment: Alignment.centerRight, child: Text(timeStr, style: TextStyle(color: isAdmin ? Colors.black54 : Colors.white24, fontSize: 9))),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Announce to members...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF161B22),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  radius: 26,
                  child: IconButton(icon: const Icon(Icons.send_rounded, color: Colors.black), onPressed: _sendMessage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
