import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:animate_do/animate_do.dart';

import 'login_view.dart';
import 'admin_dashboard.dart';
import 'member_dashboard.dart';
import 'pending_approval_view.dart';
import 'time_error_view.dart';
import 'server_time_service.dart';

class SplashView extends StatefulWidget {
  final bool isAdminEntryPoint;
  const SplashView({super.key, required this.isAdminEntryPoint});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<String> _getDeviceId() async {
    String rawId = 'unknown_device';
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      var iosDeviceInfo = await deviceInfo.iosInfo;
      rawId = iosDeviceInfo.identifierForVendor ?? 'unknown_device';
    } else if (Platform.isAndroid) {
      var androidDeviceInfo = await deviceInfo.androidInfo;
      rawId = androidDeviceInfo.id; 
    }
    return rawId.replaceAll(RegExp(r'[.#$\[\]]'), '_');
  }

  void _navigateToNext() async {
    // Wait for Splash animation
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;

    // LEVEL 0: ANTI-CHEAT TIME SYNC
    // If local clock is altered by more than 5 minutes (300,000ms), lock them out.
    if (ServerTimeService().offset.abs() > 300000) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TimeErrorView())
        );
      }
      return;
    }

    final dbRef = FirebaseDatabase.instance.ref();
    final auth = FirebaseAuth.instance;

    // LEVEL 1: Firebase Auth Persistence (Internal SQLite DB)
    // Wait briefly for auth to initialize
    int waitMs = 0;
    while (auth.currentUser == null && waitMs < 1500) {
      await Future.delayed(const Duration(milliseconds: 200));
      waitMs += 200;
    }

    final currentUser = auth.currentUser;
    if (currentUser != null) {
      // Valid session found—verify role and status in the cloud
      final userSnapshot = await dbRef.child('users/${currentUser.uid}').get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        final role = userData['role'] as String?;
        final status = userData['status'] as String? ?? 'pending';

        final bool isCorrectFlavor = (widget.isAdminEntryPoint && role == 'admin') || 
                                     (!widget.isAdminEntryPoint && role == 'member');

        if (isCorrectFlavor) {
          if (role == 'admin') {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminDashboard()));
            return;
          } else {
            if (status == 'approved') {
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MemberDashboard()));
            } else {
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PendingApprovalView()));
            }
            return;
          }
        }
      }
    }

    // LEVEL 2: Cloud Device Binding Fallback
    final deviceIdBase = await _getDeviceId();
    final sessionSnapshot = await dbRef.child('device_sessions/$deviceIdBase').get();
    
    if (sessionSnapshot.exists) {
      final sessionData = sessionSnapshot.value as Map<dynamic, dynamic>;
      final role = sessionData['role'] as String?;
      final sessionUid = sessionData['uid'] as String?;

      final bool isCorrectFlavor = (widget.isAdminEntryPoint && role == 'admin') || 
                                   (!widget.isAdminEntryPoint && role == 'member');

      if (sessionUid != null && isCorrectFlavor) {
        if (role == 'admin') {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminDashboard()));
          return;
        } else {
          final statusSnapshot = await dbRef.child('users/$sessionUid/status').get();
          final status = statusSnapshot.value as String?;
          if (status == 'approved') {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MemberDashboard()));
          } else {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PendingApprovalView()));
          }
          return;
        }
      }
    }

    // Default to login
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginView(isAdminEntryPoint: widget.isAdminEntryPoint))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeInDown(
              duration: const Duration(seconds: 1),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxHeight: 250),
                child: Image.asset(
                  'assets/images/full_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 30),
            FadeInUp(
              duration: const Duration(milliseconds: 1200),
              child: Text(
                'SLIM FITNESS',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  letterSpacing: 8,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FadeInUp(
              duration: const Duration(milliseconds: 1500),
              child: Text(
                'ELITE PERFORMANCE HUB',
                style: TextStyle(
                  letterSpacing: 4,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(height: 60),
            ZoomIn(
              duration: const Duration(milliseconds: 2000),
              child: SizedBox(
                width: 40,
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor.withOpacity(0.3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
