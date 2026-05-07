import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState
    extends State<ForgotPasswordPage> {

  final emailCtrl =
      TextEditingController();

  bool isLoading = false;

  Future<void> resetPassword() async {

    if (emailCtrl.text.trim().isEmpty) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text("Enter email"),
        ),
      );

      return;
    }

    setState(() => isLoading = true);

    try {

      await FirebaseAuth.instance
          .sendPasswordResetEmail(
        email: emailCtrl.text.trim(),
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
              "Password reset email sent"),
        ),
      );

      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
              e.message ??
                  "An error occurred"),
        ),
      );

    }

    setState(() => isLoading = false);

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title:
            const Text("Reset Password"),
      ),

      body: Center(

        child: SingleChildScrollView(

          child: Container(

            width: 350,

            padding:
                const EdgeInsets.all(24),

            child: Column(

              children: [

                const Text(
                  "Enter your email to reset password",
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

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

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(

                    onPressed:
                        isLoading
                            ? null
                            : resetPassword,

                    child: isLoading
                        ? const CircularProgressIndicator(
                            color:
                                Colors.white,
                          )
                        : const Text(
                            "Send Reset Email"),
                  ),
                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

}
