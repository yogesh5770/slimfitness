import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminConfigView extends StatefulWidget {
  const AdminConfigView({super.key});

  @override
  State<AdminConfigView> createState() => _AdminConfigViewState();
}

class _AdminConfigViewState extends State<AdminConfigView> {
  final TextEditingController _groqKeyController = TextEditingController();
  final _db = FirebaseDatabase.instance.ref();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentKeys();
  }

  void _loadCurrentKeys() async {
    final snap = await _db.child('config/keys/groq/apiKey').get();
    if (snap.exists) {
      setState(() {
        _groqKeyController.text = snap.value.toString();
      });
    }
  }

  void _saveKeys() async {
    setState(() => _isSaving = true);
    try {
      await _db.child('config/keys/groq/apiKey').set(_groqKeyController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Elite Cloud Config Updated!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Update Failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: const Text(
              'ELITE CLOUD CONFIG',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 8),
          FadeInDown(
            delay: const Duration(milliseconds: 200),
            child: const Text(
              'Manage your AI brain and system credentials in real-time.',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ),
          const SizedBox(height: 40),
          
          FadeInLeft(
            delay: const Duration(milliseconds: 400),
            child: _buildConfigCard(
              title: 'GROQ API KEY',
              subtitle: 'Daily Limit: 14,000 requests. Swap here if limited.',
              controller: _groqKeyController,
              icon: Icons.vpn_key_rounded,
            ),
          ),
          
          const Spacer(),
          
          FadeInUp(
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveKeys,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('SYNC TO CLOUD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor, size: 18),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 10)),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Paste new key here...',
              hintStyle: const TextStyle(color: Colors.white10),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
