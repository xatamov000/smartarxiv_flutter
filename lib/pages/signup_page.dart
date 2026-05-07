import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_page.dart';
import 'documents_page.dart';
import '../services/google_auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() =>
      _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {

  final emailCtrl =
      TextEditingController();

  final passwordCtrl =
      TextEditingController();

  final confirmCtrl =
      TextEditingController();

  bool obscure1 = true;
  bool obscure2 = true;

  bool isLoading = false;

  String _errorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return error.message ?? "Google signup failed";
    }

    return error.toString();
  }

  Future<void> signup() async {

    if (passwordCtrl.text !=
        confirmCtrl.text) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text("Passwords mismatch"),
        ),
      );

      return;
    }

    setState(() => isLoading = true);

    try {

      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password:
            passwordCtrl.text.trim(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const DocumentsPage(),
        ),
      );

    } on FirebaseAuthException catch (e) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
              e.message ??
                  "Signup error"),
        ),
      );

    }

    setState(() => isLoading = false);

  }

  Future<void> googleSignup() async {
    try {
      final user =
          await GoogleAuthService.signIn();

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const DocumentsPage(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text("Google signup cancelled"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(_errorMessage(e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Container(

        width: double.infinity,

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff4e73df),
              Color(0xff224abe),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: Center(

          child: SingleChildScrollView(

            child: Container(

              width: 350,

              padding:
                  const EdgeInsets.all(24),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 20,
                    color: Colors.black12,
                  )
                ],
              ),

              child: Column(

                children: [

                  const Text(
                    "Signup",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  TextField(
                    controller: emailCtrl,
                    decoration:
                        const InputDecoration(
                      labelText: "Email",
                      border:
                          OutlineInputBorder(),
                      prefixIcon:
                          Icon(Icons.email),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller:
                        passwordCtrl,
                    obscureText: obscure1,
                    decoration:
                        InputDecoration(
                      labelText:
                          "Create password",
                      border:
                          const OutlineInputBorder(),
                      prefixIcon:
                          const Icon(Icons.lock),
                      suffixIcon:
                          IconButton(
                        icon: Icon(
                          obscure1
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            obscure1 =
                                !obscure1;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller:
                        confirmCtrl,
                    obscureText: obscure2,
                    decoration:
                        InputDecoration(
                      labelText:
                          "Confirm password",
                      border:
                          const OutlineInputBorder(),
                      prefixIcon:
                          const Icon(Icons.lock),
                      suffixIcon:
                          IconButton(
                        icon: Icon(
                          obscure2
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            obscure2 =
                                !obscure2;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,

                    child: ElevatedButton(
                      onPressed:
                          isLoading
                              ? null
                              : signup,

                      child: isLoading
                          ? const CircularProgressIndicator(
                              color:
                                  Colors.white,
                            )
                          : const Text(
                              "Signup"),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(
                                horizontal: 10),
                        child: Text("Or"),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: SizedBox(
                      width: 260,
                      child: OutlinedButton.icon(

                        onPressed:
                            googleSignup,

                        icon: Image.asset(
                          'assets/google.png',
                          height: 22,
                        ),

                        label: const Text(
                          "Signup with Google",
                        ),

                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () {

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const LoginPage(),
                        ),
                      );

                    },

                    child: const Text(
                      "Already have an account? Login",
                      style: TextStyle(
                        color: Colors.blue,
                      ),
                    ),

                  ),

                ],

              ),

            ),

          ),

        ),

      ),

    );

  }

}
