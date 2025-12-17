// lib/main.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'config/app_colors.dart';
import 'models/document_model.dart';
// ✅ sahifalarni import qil
import 'pages/documents_page.dart';
import 'pages/profile_page.dart';
import 'pages/scan_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(DocumentModelAdapter());
  }
  await Hive.openBox<DocumentModel>('documents_box');

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
      initialRoute: '/documents',
      routes: {
        '/documents': (_) => const DocumentsPage(),
        '/scan': (_) => const ScanPage(),
        '/profile': (_) => const ProfilePage(),
      },
    );
  }
}
