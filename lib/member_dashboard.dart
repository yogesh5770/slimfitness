import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'ai_coach_view.dart';
import 'category_list_view.dart';
import 'exercise_video_view.dart';
import 'profile_view.dart';
import 'notification_service.dart';
import 'server_time_service.dart';

class MemberDashboard extends StatefulWidget {
  const MemberDashboard({super.key});

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    MyPlanView(),
    MemberChatView(),
    CategoryListView(isAdmin: false),
    ProfileView(),
  ];

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  void _initNotifications() async {
    final notificationService = NotificationService();
    await notificationService.init();

    // Listen for Admin broadcasts to show notifications
    final database = FirebaseDatabase.instance.ref();
    database.child('group_chat').limitToLast(1).onChildAdded.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final isAdmin = data['isAdmin'] == true;
        final senderId = data['senderId'] as String?;
        final currentUid = FirebaseAuth.instance.currentUser?.uid;

        // If it's from Admin and not us (and we're not currently on the chat tab)
        if (isAdmin && senderId != currentUid && _currentIndex != 1) {
          notificationService.showNotification(
            title: 'COUNCIL ANNOUNCEMENT',
            body: data['text'] ?? 'New message from owner',
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('SLIM FITNESS', style: TextStyle(letterSpacing: 6, fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [
          FadeInDown(
            child: IconButton(
              icon: const Icon(Icons.smart_toy_rounded),
              color: Theme.of(context).primaryColor,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiCoachView())),
            ),
          )
        ],
      ),
      body: SafeArea(
        top: true,
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF0A0C10),
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.white24,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
        unselectedLabelStyle: const TextStyle(fontSize: 10, letterSpacing: 1),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'HOME'),
          BottomNavigationBarItem(icon: Icon(Icons.forum_rounded), label: 'CHAT'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center_rounded), label: 'WORKOUT'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'PROFILE'),
        ],
      ),
    );
  }
}

class MyPlanView extends StatefulWidget {
  const MyPlanView({super.key});

  @override
  State<MyPlanView> createState() => _MyPlanViewState();
}

class _MyPlanViewState extends State<MyPlanView> {
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  final _timeService = ServerTimeService();

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Session expired.'));

    return StreamBuilder<DatabaseEvent>(
      stream: _database.child('assigned_workouts/$uid').onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        List<MapEntry<dynamic, dynamic>> todayItems = [];
        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          
          todayItems = data.entries.where((entry) {
             final item = entry.value as Map;
             final ts = item['timestamp'] as int? ?? 0;
             return _timeService.isToday(ts); // ANTI-CHEAT: Ground Truth verification
          }).toList();
        }

        if (todayItems.isEmpty) {
          return Center(
            child: FadeIn(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, size: 64, color: Colors.white.withOpacity(0.05)),
                  const SizedBox(height: 16),
                  Text('Waiting for today\'s assignment...', style: TextStyle(color: Colors.white.withOpacity(0.2), letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text('Owner will assign your workout soon.', style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 10)),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: FadeInLeft(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("YOUR TODAY'S WORKOUT", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                    Container(height: 2, width: 40, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(10))),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: todayItems.length,
                itemBuilder: (context, index) {
                  final item = todayItems[index].value as Map;
                  final key = todayItems[index].key;
                  final bool timed = item['isTimed'] == true;
                  final String status = item['status'] as String? ?? 'pending';
                  final bool isDone = status == 'done';
                  final String meta = timed ? "${item['minutes']} MINS" : "${item['sets']} SETS x ${item['reps']} REPS";

                  return FadeInUp(
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDone ? Colors.white.withOpacity(0.01) : const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isDone ? Colors.white10 : Theme.of(context).primaryColor.withOpacity(0.05)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: GestureDetector(
                          onTap: () async {
                            await _database.child('assigned_workouts/$uid/$key').update({
                              'status': isDone ? 'pending' : 'done'
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDone ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.black26, 
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: isDone ? Theme.of(context).primaryColor : Colors.transparent, width: 0.5)
                            ),
                            child: Icon(
                              isDone ? Icons.check_circle_rounded : Icons.play_circle_filled_rounded, 
                              color: isDone ? Theme.of(context).primaryColor : Colors.white24, 
                              size: 28
                            ),
                          ),
                        ),
                        title: Text(
                          item['name'] ?? '', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            letterSpacing: 0.5,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone ? Colors.white38 : Colors.white
                          )
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            isDone ? 'COMPLETED' : meta, 
                            style: TextStyle(
                              color: isDone ? Theme.of(context).primaryColor : Theme.of(context).primaryColor.withOpacity(0.6), 
                              fontWeight: FontWeight.w900, 
                              fontSize: 10,
                              letterSpacing: 1
                            )
                          ),
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseVideoView(exerciseName: item['name']!, videoUrl: item['link']!)));
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class MemberChatView extends StatefulWidget {
  const MemberChatView({super.key});

  @override
  State<MemberChatView> createState() => _MemberChatViewState();
}

class _MemberChatViewState extends State<MemberChatView> {
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  final _timeService = ServerTimeService();
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _handleDailyPurge();
  }

  void _handleDailyPurge() async {
    // ELITE PURGE: Check if a new day has started in the cloud
    final serverNow = _timeService.now;
    final dateKey = "${serverNow.year}-${serverNow.month}-${serverNow.day}";
    
    final lastPurgeSnapshot = await _database.child('metadata/last_purge').get();
    final lastPurgeDate = lastPurgeSnapshot.value as String?;

    if (lastPurgeDate != dateKey) {
      // NEW DAY: Empty ALL chat
      await _database.child('group_chat').remove();
      // Record the purge date to prevent double-wipe
      await _database.child('metadata/last_purge').set(dateKey);
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // ELITE IDENTITY: Fetch actual member name from the User node
      final profileSnapshot = await _database.child('users/${user.uid}/name').get();
      String senderName = profileSnapshot.value as String? ?? user.email?.split('@')[0] ?? 'Member';
      
      // If it's the Admin account, capitalize as OWNER
      if (user.email == 'slimfitness@gmail.com') senderName = 'YOGESH (OWNER)';

      await _database.child('group_chat').push().set({
        'senderId': user.uid,
        'senderName': senderName,
        'text': text,
        'isAdmin': user.email == 'slimfitness@gmail.com',
        'timestamp': ServerValue.timestamp,
      });
      _messageController.clear();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = _auth.currentUser?.uid;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: _database.child('group_chat').onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data?.snapshot.value == null) return const Center(child: Text('No messages yet.', style: TextStyle(color: Colors.white24)));

              final Map<dynamic, dynamic> chatMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              final messages = chatMap.values.map((v) => Map<String, dynamic>.from(v as Map)).toList();
              messages.sort((a, b) => (a['timestamp'] as int? ?? 0).compareTo(b['timestamp'] as int? ?? 0));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg['senderId'] == currentUserUid;
                  final isAdmin = msg['isAdmin'] == true;
                  final date = DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] as int? ?? 0);
                  final timeStr = DateFormat('hh:mm a').format(date);

                  return FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    child: Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).primaryColor : (isAdmin ? const Color(0xFF1E293B) : const Color(0xFF161B22)),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isMe ? 20 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isAdmin) const Text('OWNER', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1))
                            else if (!isMe) Text(msg['senderName'] ?? '', style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text(msg['text'] ?? '', style: TextStyle(color: isMe ? Colors.black : Colors.white, fontSize: 15)),
                            const SizedBox(height: 4),
                            Align(alignment: Alignment.centerRight, child: Text(timeStr, style: TextStyle(color: isMe ? Colors.black54 : Colors.white24, fontSize: 9))),
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
                    hintText: 'Type a message...',
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
    );
  }
}
