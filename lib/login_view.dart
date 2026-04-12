import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:animate_do/animate_do.dart';

import 'admin_dashboard.dart';
import 'member_dashboard.dart';
import 'pending_approval_view.dart';
import 'register_view.dart'; 
import 'package:google_sign_in/google_sign_in.dart';

class LoginView extends StatefulWidget {
  final bool isAdminEntryPoint;
  const LoginView({super.key, required this.isAdminEntryPoint});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

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

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Required fields missing', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent.withOpacity(0.9),
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final deviceId = await _getDeviceId();
      final dbRef = FirebaseDatabase.instance.ref();
      final auth = FirebaseAuth.instance;

      if (widget.isAdminEntryPoint) {
        if (email == 'slimfitness@gmail.com' && password == 'slimfitness@123') {
          UserCredential userCred = await auth.signInWithEmailAndPassword(email: email, password: password);
          final uid = userCred.user?.uid ?? 'admin_user';
          
          // Save to Cloud Persistence (Our elite handshake)
          await dbRef.child('device_sessions/$deviceId').set({
            'uid': uid, 
            'role': 'admin',
            'email': email,
            'lastLogin': ServerValue.timestamp
          });

          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminDashboard()));
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Admin Credentials')));
        }
      } else {
        UserCredential userCred = await auth.signInWithEmailAndPassword(email: email, password: password);
        final user = userCred.user;
        if (user != null) {
          // Save to Cloud Persistence (Our elite handshake)
          await dbRef.child('device_sessions/$deviceId').set({
            'uid': user.uid, 
            'role': 'member',
            'email': user.email,
            'lastLogin': ServerValue.timestamp
          });

          final snapshot = await dbRef.child('users/${user.uid}/status').get();
          final status = snapshot.value as String?;
          if (!mounted) return;
          if (status == 'approved') {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MemberDashboard()));
          } else {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PendingApprovalView()));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final auth = FirebaseAuth.instance;
      final dbRef = FirebaseDatabase.instance.ref();
      final deviceId = await _getDeviceId();

      UserCredential userCred = await auth.signInWithCredential(credential);
      final user = userCred.user;

      if (user != null) {
        final role = widget.isAdminEntryPoint ? 'admin' : 'member';
        
        // Save to Cloud Persistence (Elite Handshake)
        await dbRef.child('device_sessions/$deviceId').set({
          'uid': user.uid, 
          'role': role,
          'email': user.email,
          'lastLogin': ServerValue.timestamp
        });

        // Check if user exists
        final snapshot = await dbRef.child('users/${user.uid}').get();
        if (!snapshot.exists) {
          // New User
          await dbRef.child('users/${user.uid}').set({
            'name': user.displayName ?? (widget.isAdminEntryPoint ? 'Elite Admin' : 'Elite Member'),
            'email': user.email,
            'status': widget.isAdminEntryPoint ? 'approved' : 'pending',
            'role': role,
            'createdAt': ServerValue.timestamp,
          });
          if (!mounted) return;
          if (widget.isAdminEntryPoint) {
             Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminDashboard()));
          } else {
             Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PendingApprovalView()));
          }
        } else {
          // Existing User
          final data = snapshot.value as Map<dynamic, dynamic>;
          if (!mounted) return;
          final userRole = data['role'] as String? ?? 'member';
          final userStatus = data['status'] as String? ?? 'pending';

          if (widget.isAdminEntryPoint && userRole == 'admin') {
             Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminDashboard()));
          } else if (!widget.isAdminEntryPoint && userRole == 'member' && userStatus == 'approved') {
             Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MemberDashboard()));
          } else if (!widget.isAdminEntryPoint && userRole == 'member') {
             Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PendingApprovalView()));
          } else {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Portal Mismatch: Use the correct flavor.')));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Sign-In Error: $e')));
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
                  image: const NetworkImage('https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&q=80&w=800'),
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
                              widget.isAdminEntryPoint ? 'ADMIN PORTAL' : 'ELITE ACCESS',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2.5, fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                            const SizedBox(height: 35),
                            
                            if (!widget.isAdminEntryPoint) ...[
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                                  icon: Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                                    height: 20,
                                  ),
                                  label: const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 15)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 25),
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Text('OR', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                                ],
                              ),
                              const SizedBox(height: 25),
                            ],

                            _buildLoginField(_emailController, 'Account Email or Phone', Icons.email_outlined),
                            const SizedBox(height: 16),
                            _buildLoginField(_passwordController, 'Security Key', Icons.lock_outline, isPass: true),
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
                                      onPressed: _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).primaryColor,
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                        elevation: 0,
                                      ),
                                      child: const Text('AUTHENTICATE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                    ),
                                  ),
                                  if (!widget.isAdminEntryPoint) ...[
                                    const SizedBox(height: 20),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterView()));
                                      },
                                      child: Text(
                                        'New Member? Create Account',
                                        style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                      ),
                                    ),
                                  ]
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


  Widget _buildLoginField(TextEditingController controller, String hint, IconData icon, {bool isPass = false}) {
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
