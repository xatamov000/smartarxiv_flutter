import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'signup_page.dart';
import 'documents_page.dart';
import '../services/google_auth_service.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  bool isLoading = false;
  bool obscure = true;

  String _errorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return error.message ?? "Google login failed";
    }

    return error.toString();
  }

  Future<void> login() async {

    setState(() => isLoading = true);

    try {

      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
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
            e.message ?? "Login error",
          ),
        ),
      );

    }

    setState(() => isLoading = false);

  }

  Future<void> googleLogin() async {
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
            content: Text(
              "Google login cancelled",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            _errorMessage(e),
          ),
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
              padding: const EdgeInsets.all(24),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 20,
                    color: Colors.black12,
                  ),
                ],
              ),

              child: Column(

                children: [

                  const Text(
                    "Login",
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
                    obscureText: obscure,
                    decoration:
                        InputDecoration(
                      labelText: "Password",
                      border:
                          const OutlineInputBorder(),
                      prefixIcon:
                          const Icon(Icons.lock),
                      suffixIcon:
                          IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            obscure =
                                !obscure;
                          });
                        },
                      ),
                    ),
                  ),

                  Align(
                    alignment:
                        Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ForgotPasswordPage(),
                          ),
                        );

                      },
                      child: const Text(
                          "Forgot password?"),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          isLoading
                              ? null
                              : login,
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color:
                                  Colors.white,
                            )
                          : const Text(
                              "Login"),
                    ),
                  ),

                  const SizedBox(height: 14),

                  GestureDetector(
                    onTap: () {

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const SignupPage(),
                        ),
                      );

                    },
                    child: const Text(
                      "Don't have an account? Signup",
                      style: TextStyle(
                        color: Colors.blue,
                      ),
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

                        onPressed: googleLogin,

                        icon: Image.asset(
                          'assets/google.png',
                          height: 22,
                        ),

                        label: const Text(
                          "Login with Google",
                        ),

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
