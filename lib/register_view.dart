import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'pending_approval_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  
  bool _isLoading = false;
  bool _otpSent = false;
  String? _verificationId;
  PhoneAuthCredential? _autoVerifiedCred;

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone number first')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Ensure phone number has country code. Default to +91 for India if missing
      String formattedPhone = phone;
      if (!formattedPhone.startsWith('+')) {
        formattedPhone = '+91$formattedPhone';
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          setState(() {
            _autoVerifiedCred = credential;
            _otpSent = true;
            _isLoading = false;
            _otpController.text = 'AUTO-VERIFIED';
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Phone Auto-Verified!'),
            backgroundColor: Theme.of(context).primaryColor,
          ));
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification Failed: ${e.message}')));
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('OTP SMS Sent!'),
            backgroundColor: Theme.of(context).primaryColor,
          ));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All fields required')));
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    if (!_otpSent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please send OTP first by tapping SEND OTP')));
      return;
    }
    if (otp.isEmpty && _autoVerifiedCred == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the OTP received via SMS')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = FirebaseAuth.instance;
      final dbRef = FirebaseDatabase.instance.ref();
      
      // 1. Verify OTP and sign in with Phone
      PhoneAuthCredential cred = _autoVerifiedCred ?? PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      
      UserCredential userCred = await auth.signInWithCredential(cred);
      final user = userCred.user;

      if (user != null) {
        // 2. Link Email & Password so they can login with it later
        AuthCredential emailCred = EmailAuthProvider.credential(email: email, password: password);
        try {
          await user.linkWithCredential(emailCred);
        } catch (linkError) {
          throw Exception('Failed to link Email/Password. Email might already be in use.');
        }

        // 3. Save User Profile to DB
        await dbRef.child('users/${user.uid}').set({
          'name': name,
          'phone': phone,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration Error: $e')));
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

      UserCredential userCred = await auth.signInWithCredential(credential);
      final user = userCred.user;

      if (user != null) {
        // Check if user exists
        final snapshot = await dbRef.child('users/${user.uid}').get();
        if (!snapshot.exists) {
          // New User
          await dbRef.child('users/${user.uid}').set({
            'name': user.displayName ?? 'Elite Member',
            'email': user.email,
            'status': 'pending',
            'role': 'member',
            'createdAt': ServerValue.timestamp,
          });
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PendingApprovalView()),
            (route) => false,
          );
        } else {
          // Existing User
          final data = snapshot.value as Map<dynamic, dynamic>;
          if (!mounted) return;
          if (data['status'] == 'approved') {
            Navigator.pop(context); // Go back to login to handle session
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const PendingApprovalView()),
              (route) => false,
            );
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
                  image: const NetworkImage('https://images.unsplash.com/photo-1517836357463-d25dfeac3438?q=80&w=800'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.darken),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
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
                            Text(
                              'VERIFY IDENTITY',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2.5, fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                            const SizedBox(height: 35),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _handleGoogleSignIn,
                                icon: Image.network(
                                  'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                                  height: 20,
                                ),
                                label: const Text('Sign up with Google', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 15)),
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
                                  child: Text('OR USE PHONE', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                              ],
                            ),
                            const SizedBox(height: 25),
                            
                            // NAME
                            _buildField(_nameController, 'Full Name', Icons.person_outline),
                            const SizedBox(height: 16),
                            
                            // PHONE
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildField(_phoneController, 'Phone Number', Icons.phone_android, keyboard: TextInputType.phone),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 1,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _sendOtp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).primaryColor,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      elevation: 0,
                                    ),
                                    child: const Text('SEND OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                              ],
                            ),
                            
                            // OTP FIELD (Visible only after sending)
                            if (_otpSent) ...[
                              const SizedBox(height: 16),
                              FadeIn(
                                child: _buildField(_otpController, 'Enter 6-Digit SMS OTP', Icons.message, keyboard: TextInputType.number),
                              ),
                            ],
                            
                            const SizedBox(height: 16),
                            
                            // EMAIL
                            _buildField(_emailController, 'Account Email', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                            const SizedBox(height: 16),
                            
                            // PASSWORDS
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

  Widget _buildField(TextEditingController controller, String hint, IconData icon, {bool isPass = false, TextInputType? keyboard}) {
    return TextField(
      controller: controller,
      obscureText: isPass,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.5), size: 20),
        filled: true,
        fillColor: Colors.black38,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3))),
      ),
    );
  }
}
