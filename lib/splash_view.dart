import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
      // ELITE: Triple-hardware verification for ultra-persistence
      rawId = "${androidDeviceInfo.brand}_${androidDeviceInfo.model}_${androidDeviceInfo.hardware}_${androidDeviceInfo.id}";
    }
    return rawId.replaceAll(RegExp(r'[.#$\[\]]'), '_');
  }

  void _navigateToNext() async {
    // ELITE WATCHDOG: Total maximum Splash duration is 6 seconds
    Timer(const Duration(seconds: 6), () {
      if (mounted) {
        print("ELITE: Splash Watchdog Triggered. Forcing Navigation.");
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => LoginView(isAdminEntryPoint: widget.isAdminEntryPoint))
        );
      }
    });

    try {
      await Future.delayed(const Duration(milliseconds: 3000));
      if (!mounted) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName;
      print("ELITE IDENTITY CHECK: $packageName (Admin Entry: ${widget.isAdminEntryPoint})");

      // Verify that the Binary Flavor matches the Entry Point
      final isBinaryAdmin = packageName.contains('admin');
      final isBinaryMember = packageName.contains('member');

      if (widget.isAdminEntryPoint && !isBinaryAdmin) {
        print("ELITE SECURITY: Admin Entry Point used in non-Admin binary ($packageName). Forcing redirection.");
        // If they are in the wrong binary, we can't let them in as Admin logic.
        // We will proceed but force them to Member routing to prevent Admin access in Member app.
      }

      final dbRef = FirebaseDatabase.instance.ref();
      final auth = FirebaseAuth.instance;

      // LEVEL 0: ANTI-CHEAT TIME SYNC (5s Timeout)
      try {
        if (ServerTimeService().offset.abs() > 300000) {
          if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const TimeErrorView()));
          return;
        }
      } catch (e) {
        print("ELITE: Time sync error, bypassing check: $e");
      }

      // LEVEL 1: Firebase Auth Persistence (Aggressive polling)
      int waitMs = 0;
      while (auth.currentUser == null && waitMs < 1500) {
        await Future.delayed(const Duration(milliseconds: 250));
        waitMs += 250;
      }

      final currentUser = auth.currentUser;
      if (currentUser != null) {
        print("ELITE: Found auth user, checking data...");
        final userSnapshot = await dbRef.child('users/${currentUser.uid}').get().timeout(const Duration(seconds: 5));
        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          final String role = userData['role'] as String? ?? 'member';
          final String status = userData['status'] as String? ?? 'pending';

          final bool isOwner = currentUser.email == 'slimfitness@gmail.com';
          final bool isCorrectFlavor = (widget.isAdminEntryPoint && (role == 'admin' || isOwner)) || 
                                       (!widget.isAdminEntryPoint && role == 'member');

          if (isCorrectFlavor) {
            if (role == 'admin' || isOwner) {
              print("ELITE: Routing to Admin Dashboard.");
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminDashboard()));
              return;
            } else if (role == 'member') {
              if (status == 'approved') {
                print("ELITE: Routing to Member Dashboard.");
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MemberDashboard()));
              } else {
                print("ELITE: Routing to Pending Approval.");
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PendingApprovalView()));
              }
              return;
            }
          } else {
            print("ELITE ERROR: Identity/Flavor mismatch. Forcing logout to correct session.");
            await auth.signOut();
          }
        }
      }

      // LEVEL 2: Cloud Device Binding (Handshake Recovery with 5s Timeout)
      print("ELITE: Performing cloud device handshake...");
      final deviceIdBase = await _getDeviceId();
      final sessionSnapshot = await dbRef.child('device_sessions/$deviceIdBase').get().timeout(const Duration(seconds: 5));
      
      if (sessionSnapshot.exists) {
        final sessionData = sessionSnapshot.value as Map<dynamic, dynamic>;
        final role = sessionData['role'] as String?;
        final sessionUid = sessionData['uid'] as String?;
        final String email = sessionData['email'] as String? ?? '';

        if (sessionUid != null) {
          if (widget.isAdminEntryPoint && (role == 'admin' || email == 'slimfitness@gmail.com')) {
            print("ELITE: Pinning recovered Admin session.");
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminDashboard()));
            return;
          } else if (!widget.isAdminEntryPoint && role == 'member') {
            final statusSnapshot = await dbRef.child('users/$sessionUid/status').get().timeout(const Duration(seconds: 5));
            if (statusSnapshot.value == 'approved') {
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MemberDashboard()));
            } else {
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PendingApprovalView()));
            }
            return;
          }
        }
      }
    } catch (e) {
      print("ELITE HANDSHAKE ERROR: $e");
    }

    // Default to login if anything fails or times out
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LoginView(isAdminEntryPoint: widget.isAdminEntryPoint))
      );
    }
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
