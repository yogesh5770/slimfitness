import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'admin_approvals_view.dart';
import 'admin_broadcast_view.dart';
import 'category_list_view.dart';
import 'admin_members_view.dart';
import 'admin_food_db_view.dart';
import 'notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'admin_config_view.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 1;

  final List<Widget> _pages = const [
    OwnerApprovalsView(),
    CategoryListView(isAdmin: true),
    AdminMembersView(),
    AdminConfigView(),
    AdminFoodDbView(),
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

    final database = FirebaseDatabase.instance.ref();
    database.child('group_chat').limitToLast(1).onChildAdded.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final isAdmin = data['isAdmin'] == true;
        final senderName = data['senderName'] as String? ?? 'Member';

        if (!isAdmin && _currentIndex != 5) {
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
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
          unselectedLabelStyle: const TextStyle(fontSize: 8),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.verified_user_rounded, size: 20), label: 'APPROVE'),
            BottomNavigationBarItem(icon: Icon(Icons.fitness_center_rounded, size: 20), label: 'WORKOUT'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded, size: 20), label: 'MEMBERS'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_suggest_rounded, size: 20), label: 'CONFIG'),
            BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_rounded, size: 20), label: 'FOOD DB'),
            BottomNavigationBarItem(icon: Icon(Icons.forum_rounded, size: 20), label: 'CHAT'),
          ],
        ),
      ),
    );
  }
}
