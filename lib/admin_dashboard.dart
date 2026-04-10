import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'admin_approvals_view.dart';
import 'admin_broadcast_view.dart';
import 'category_list_view.dart';
import 'admin_members_view.dart';

import 'admin_members_view.dart';
import 'notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 1; // Default to Library

  final List<Widget> _pages = const [
    OwnerApprovalsView(),
    CategoryListView(isAdmin: true),
    AdminMembersView(),
    BroadcastMessageView(),
  ];

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  void _initNotifications() async {
    final notificationService = NotificationService();
    await notificationService.init();

    // Listen for Member messages to show notifications to Admin
    final database = FirebaseDatabase.instance.ref();
    database.child('group_chat').limitToLast(1).onChildAdded.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final isAdmin = data['isAdmin'] == true;
        final senderName = data['senderName'] as String? ?? 'Member';

        // If it's from a Member (not admin) and we're not currently on the Council tab
        if (!isAdmin && _currentIndex != 3) {
          notificationService.showNotification(
            title: 'NEW MEMBER MESSAGE',
            body: '$senderName: ${data['text'] ?? 'New message'}',
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
      ),
      body: SafeArea(child: _pages[_currentIndex]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0C10),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.white24,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.verified_user_rounded), label: 'APPROVE'),
            BottomNavigationBarItem(icon: Icon(Icons.fitness_center_rounded), label: 'WORKOUT'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'MEMBERS'),
            BottomNavigationBarItem(icon: Icon(Icons.forum_rounded), label: 'CHAT'),
          ],
        ),
      ),
    );
  }
}
