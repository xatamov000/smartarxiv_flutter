// lib/main.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/app_colors.dart';
import 'models/document_model.dart';
import 'pages/documents_page.dart';
import 'pages/profile_page.dart';
import 'pages/scan_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase initialize qilish
  await Firebase.initializeApp();

  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(DocumentModelAdapter());
  }

  await Hive.openBox<DocumentModel>('documents_box');
  await Hive.openBox('profile_box');
  await Hive.openBox('settings_box');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: false,
      ),
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignupPage(),
        '/documents': (_) => const DocumentsPage(),
        '/scan': (_) => const ScanPage(),
        '/profile': (_) => const ProfilePage(),
      },
    );
  }
}
