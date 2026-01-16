// lib/pages/profile_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_colors.dart';
import '../models/document_model.dart';
import 'widgets/bottom_nav.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _picker = ImagePicker();

  Box get _profile => Hive.box('profile_box');
  Box<DocumentModel> get _docs => Hive.box<DocumentModel>('documents_box');

  String get _name {
    final v = (_profile.get('name') ?? '').toString().trim();
    return v.isEmpty ? "Foydalanuvchi" : v;
  }

  String get _email {
    final v = (_profile.get('email') ?? '').toString().trim();
    return v.isEmpty ? "email@example.com" : v;
  }

  String? get _avatarPath {
    final v = (_profile.get('avatar_path') ?? '').toString().trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _editProfile() async {
    final nameCtrl = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Profilni tahrirlash"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Ism",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Bekor"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Saqlash"),
              ),
            ],
          ),
    );

    if (ok == true) {
      await _profile.put('name', nameCtrl.text.trim());
      await _profile.put('email', emailCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✅ Profil saqlandi")));
    }

    nameCtrl.dispose();
    emailCtrl.dispose();
  }

  Future<void> _pickAvatar(ImageSource src) async {
    try {
      final x = await _picker.pickImage(
        source: src,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (x == null) return;

      await _profile.put('avatar_path', x.path);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✅ Avatar yangilandi")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Avatar xatolik: $e")));
    }
  }

  Future<void> _avatarSheet() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder:
          (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(title: Text("Avatar")),
                ListTile(
                  leading: const Icon(Icons.photo),
                  title: const Text("Gallery"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAvatar(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text("Camera"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAvatar(ImageSource.camera);
                  },
                ),
                if (_avatarPath != null)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      "Avatarni olib tashlash",
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _profile.delete('avatar_path');
                    },
                  ),
                const SizedBox(height: 10),
              ],
            ),
          ),
    );
  }

  Future<int> _calcTotalBytes(List<DocumentModel> docs) async {
    int total = 0;
    for (final d in docs) {
      final path = d.filePath; // String yoki String? bo‘lishi mumkin
      if (path == null || path.trim().isEmpty) continue;

      try {
        final f = File(path);
        if (await f.exists()) total += await f.length();
      } catch (_) {}
    }
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  Future<void> _logout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Chiqish"),
            content: const Text(
              "Profil ma’lumotlari (ism/email/avatar) tozalanadi.\n"
              "Hujjatlar (Documents) o‘chmaydi.\n\n"
              "Davom etamizmi?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Bekor"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Chiqish"),
              ),
            ],
          ),
    );

    if (yes != true) return;

    await _profile.delete('name');
    await _profile.delete('email');
    await _profile.delete('avatar_path');

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("✅ Chiqildi")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const BottomNav(currentIndex: 2),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Profil 👤",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Shaxsiy ma'lumotlaringiz",
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // USER CARD
              ValueListenableBuilder(
                valueListenable: _profile.listenable(),
                builder: (_, __, ___) {
                  final avatar = _avatarPath;
                  final hasAvatar = avatar != null && File(avatar).existsSync();

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowLight,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _avatarSheet,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 35,
                                backgroundColor: Colors.grey.shade300,
                                backgroundImage:
                                    hasAvatar ? FileImage(File(avatar!)) : null,
                                child:
                                    hasAvatar
                                        ? null
                                        : const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.shadowMedium,
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _email,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _editProfile,
                          icon: const Icon(Icons.edit),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // STATS
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowLight,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ValueListenableBuilder(
                  valueListenable: _docs.listenable(),
                  builder: (_, Box<DocumentModel> box, __) {
                    final docs = box.values.toList();
                    final docxCount =
                        docs.where((d) {
                          final t = (d.fileType ?? '').toString().toLowerCase();
                          return t == 'docx';
                        }).length;

                    return FutureBuilder<int>(
                      future: _calcTotalBytes(docs),
                      builder: (_, snap) {
                        final bytes = snap.data ?? 0;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _Stat(
                              label: "Documents",
                              value: "${docs.length}",
                              icon: Icons.folder,
                            ),
                            _Stat(
                              label: "DOCX",
                              value: "$docxCount",
                              icon: Icons.insert_drive_file,
                            ),
                            _Stat(
                              label: "Storage",
                              value: _formatBytes(bytes),
                              icon: Icons.storage,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 26),

              Center(
                child: InkWell(
                  onTap: _logout,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          "Chiqish",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ✅ Hech qanday Settings/About tile yo‘q
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
