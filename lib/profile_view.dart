import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:animate_do/animate_do.dart';
import 'splash_view.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();

  Future<String> _getDeviceId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) return (await deviceInfo.iosInfo).identifierForVendor ?? 'unknown';
    return (await deviceInfo.androidInfo).id;
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to end this session?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmed == true) {
      final deviceId = await _getDeviceId();
      await _db.child('device_sessions/${deviceId.replaceAll(RegExp(r'[.#$\[\]]'), '_')}').remove();
      await _auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashView(isAdminEntryPoint: false)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Center(child: Text('Not logged in'));

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            FadeInDown(
              child: Center(
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                  ),
                  child: Icon(Icons.person_rounded, size: 60, color: Theme.of(context).primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeInUp(
              child: Text(
                user.email?.split('@')[0].toUpperCase() ?? 'MEMBER',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 8),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Text(user.email ?? '', style: const TextStyle(color: Colors.white38)),
            ),
            const SizedBox(height: 40),
            _buildProfileTile(Icons.verified_user_rounded, 'Membership', 'ACTIVE ELITE', Theme.of(context).primaryColor),
            _buildProfileTile(Icons.calendar_today_rounded, 'Joined', 'APRIL 2026', Colors.white38),
            _buildProfileTile(Icons.info_outline_rounded, 'Version', '1.0.50 (Elite)', Colors.white38),
            const SizedBox(height: 60),
            FadeIn(
              delay: const Duration(milliseconds: 500),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  label: const Text('END SECURE SESSION', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent, width: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white24, size: 24),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }
}
