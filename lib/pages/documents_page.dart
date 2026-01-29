// lib/pages/documents_page.dart
//
// 🔥 BACKEND WAKE-UP QOSHILDI - Ilova ochilganda backend uyg'onadi
//

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_colors.dart';
import '../models/document_model.dart';
import '../services/api_service.dart'; // 🔥 YANGI
import 'widgets/bottom_nav.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  late final Future<Box<DocumentModel>> _boxFuture;
  bool _backendWaking = false; // 🔥 YANGI

  @override
  void initState() {
    super.initState();
    _boxFuture = Hive.openBox<DocumentModel>('documents_box');

    // 🔥 YANGI: Backend'ni background'da uyg'ot
    _wakeUpBackend();
  }

  /// 🔥 YANGI: Backend'ni uyg'otish (Render cold start uchun)
  Future<void> _wakeUpBackend() async {
    setState(() => _backendWaking = true);

    try {
      final api = ApiService();
      debugPrint("🔔 Backend uyg'otilmoqda...");

      // 90 sekund timeout bilan
      await api.checkHealth().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          debugPrint("⏱️ Backend timeout (normal, Render cold start)");
          return false;
        },
      );

      debugPrint("✅ Backend tayyor!");
    } catch (e) {
      debugPrint("⚠️ Backend uyg'onmadi: $e");
      // Xatolik bo'lsa ham davom et (offline ishlashi mumkin)
    } finally {
      if (mounted) {
        setState(() => _backendWaking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const BottomNav(currentIndex: 0),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: AppColors.primary,
          statusBarIconBrightness: Brightness.light,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(),

              // 🔥 YANGI: Backend uyg'onayotganini ko'rsatish
              if (_backendWaking)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  color: Colors.orange.shade50,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Backend uyg'onmoqda... (30-60 sek)",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<Box<DocumentModel>>(
                  future: _boxFuture,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snap.hasError || !snap.hasData) {
                      final msg =
                          snap.error?.toString() ?? "Box ochilmadi (no data)";
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            "❌ Hive xatolik: $msg",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }

                    final box = snap.data!;
                    return ValueListenableBuilder(
                      valueListenable: box.listenable(),
                      builder: (_, Box<DocumentModel> bx, __) {
                        final docs = bx.values.toList().reversed.toList();

                        if (docs.isEmpty) {
                          return _buildEmptyState();
                        }

                        return _buildDocumentList(docs);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/scan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Yangi scan"),
      ),
    );
  }

  // ... Qolgan kodlar bir xil qoladi ...

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "SmartArxiv",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Hujjatlaringiz",
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Hujjatlarni qidirish...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        onChanged: (value) {
          // TODO: Qidiruv logikasi
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Hech qanday hujjat yo'q",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Yangi scan qiling",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList(List<DocumentModel> docs) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        return Card(
          key: ValueKey(doc.filePath),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              doc.fileType == 'pdf' ? Icons.picture_as_pdf : Icons.description,
              color: AppColors.primary,
              size: 32,
            ),
            title: Text(
              doc.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _formatDate(doc.createdAt),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new),
                          SizedBox(width: 8),
                          Text("Ochish"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share),
                          SizedBox(width: 8),
                          Text("Ulashish"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            "O'chirish",
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
                switch (value) {
                  case 'open':
                    _openDocument(doc);
                    break;
                  case 'share':
                    _shareDocument(doc);
                    break;
                  case 'delete':
                    _deleteDocument(index);
                    break;
                }
              },
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}.${date.month}.${date.year}";
  }

  Future<void> _openDocument(DocumentModel doc) async {
    await OpenFile.open(doc.filePath);
  }

  Future<void> _shareDocument(DocumentModel doc) async {
    await Share.shareXFiles([XFile(doc.filePath)]);
  }

  Future<void> _deleteDocument(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("O'chirish"),
            content: const Text("Hujjatni o'chirishni xohlaysizmi?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Yo'q"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Ha, o'chirish"),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      try {
        final box = await _boxFuture;
        final docs = box.values.toList().reversed.toList();
        final doc = docs[index];

        // Faylni o'chirish
        final file = File(doc.filePath);
        if (await file.exists()) {
          await file.delete();
        }

        // Hive'dan o'chirish
        final key = box.keys.firstWhere(
          (k) => box.get(k) == doc,
          orElse: () => null,
        );
        if (key != null) {
          await box.delete(key);
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("✅ Hujjat o'chirildi")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("❌ Xatolik: $e")));
        }
      }
    }
  }
}
