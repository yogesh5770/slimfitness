import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:animate_do/animate_do.dart';
import 'pending_approval_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All fields required')));
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = FirebaseAuth.instance;
      final dbRef = FirebaseDatabase.instance.ref();
      
      UserCredential userCred = await auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = userCred.user;

      if (user != null) {
        await dbRef.child('users/${user.uid}').set({
          'name': name,
          'email': email,
          'status': 'pending',
          'role': 'member',
          'createdAt': ServerValue.timestamp,
        });

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PendingApprovalView()),
          (route) => false,
        );
      }
    }
 catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                image: DecorationImage(
                  image: const NetworkImage('https://images.unsplash.com/photo-1517836357463-d25dfeac3438?q=80&w=800'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.darken),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 1000),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.all(35),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(35),
                          border: Border.all(color: Colors.white.withOpacity(0.04)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(maxHeight: 120),
                              child: Image.asset('assets/images/full_logo.png', fit: BoxFit.contain),
                            ),
                            const SizedBox(height: 25),
                            Text(
                              'JOIN THE ELITE',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2.5, fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                            const SizedBox(height: 35),
                            _buildField(_nameController, 'Full Name', Icons.person_outline),
                            const SizedBox(height: 16),
                            _buildField(_emailController, 'Enter Email', Icons.email_outlined),
                            const SizedBox(height: 16),
                            _buildField(_passwordController, 'Create Password', Icons.lock_outline, isPass: true),
                            const SizedBox(height: 16),
                            _buildField(_confirmController, 'Confirm Password', Icons.lock_outline, isPass: true),
                            const SizedBox(height: 35),
                            if (_isLoading)
                               CircularProgressIndicator(color: Theme.of(context).primaryColor)
                            else
                              Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 58,
                                    child: ElevatedButton(
                                      onPressed: _handleRegister,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).primaryColor,
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                        elevation: 0,
                                      ),
                                      child: const Text('SUBMIT APPLICATION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      'Already a member? Login',
                                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String hint, IconData icon, {bool isPass = false}) {
    return TextField(
      controller: controller,
      obscureText: isPass,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.5), size: 22),
        filled: true,
        fillColor: Colors.black38,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3))),
      ),
    );
  }
}
