import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'member_dashboard.dart';
import 'login_view.dart';

class PendingApprovalView extends StatefulWidget {
  const PendingApprovalView({super.key});

  @override
  State<PendingApprovalView> createState() => _PendingApprovalViewState();
}

class _PendingApprovalViewState extends State<PendingApprovalView> {
  late final StreamSubscription<DatabaseEvent> _statusSubscription;
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _listenForApproval();
  }

  void _listenForApproval() {
    final user = _auth.currentUser;
    if (user == null) return;

    _statusSubscription = _database.child('users/${user.uid}/status').onValue.listen((event) {
      if (event.snapshot.value == 'approved') {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MemberDashboard()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription.cancel();
    super.dispose();
  }

  void _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginView(isAdminEntryPoint: false)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_bottom, size: 80, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 24),
              const Text(
                'PENDING APPROVAL',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your account registration has been submitted and is currently being reviewed by the gym owner.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              const SizedBox(height: 48),
              TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.white54),
                label: const Text('Sign Out', style: TextStyle(color: Colors.white54)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
