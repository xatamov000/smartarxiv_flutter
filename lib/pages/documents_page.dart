// lib/pages/documents_page.dart
//
// Documents list UI (auto-refresh) — FIXED:
// - openBoxForUi yo‘q (DocumentService'ga bog‘lanmaydi)
// - Hive box FutureBuilder bilan ochiladi
// - Box o'zgarsa list avtomatik yangilanadi (ValueListenableBuilder)
// - UI listda key saqlanadi => delete/rename adashmaydi
// - PDF / DOCX badge + open/rename/share/delete
// - Delete confirm dialog bor
// - context async gap warninglar kamaytirildi

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_colors.dart';
import '../models/document_model.dart';
import 'widgets/bottom_nav.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  late final Future<Box<DocumentModel>> _boxFuture;

  @override
  void initState() {
    super.initState();
    // ✅ main.dart box ochgan bo‘lsa ham, openBox qayta chaqirilsa muammo qilmaydi
    _boxFuture = Hive.openBox<DocumentModel>('documents_box');
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
                    return ValueListenableBuilder<Box<DocumentModel>>(
                      valueListenable: box.listenable(),
                      builder: (context, b, _) {
                        final entries =
                            b.toMap().entries.toList().reversed.toList();

                        if (entries.isEmpty) {
                          return const Center(
                            child: Text(
                              "Hozircha hujjatlar yo‘q",
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }

                        return _buildDocumentList(entries, b);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader() {
    return Container(
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
            "SmartArxiv 🔐",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Barcha hujjatlar bir joyda",
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH (hozircha UI)
  // ============================================================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: Colors.black54),
            SizedBox(width: 10),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "Hujjatlarni qidirish...",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LIST (entries: key + model)
  // ============================================================
  Widget _buildDocumentList(
    List<MapEntry<dynamic, DocumentModel>> entries,
    Box<DocumentModel> box,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final key = entry.key;
        final doc = entry.value;

        final type = doc.resolvedType;

        final iconData =
            type == "pdf"
                ? Icons.picture_as_pdf
                : (type == "docx"
                    ? Icons.description
                    : Icons.insert_drive_file);

        final iconColor =
            type == "pdf"
                ? Colors.red
                : (type == "docx" ? AppColors.primary : Colors.grey);

        final typeLabel =
            type == "pdf" ? "PDF" : (type == "docx" ? "DOCX" : "FILE");

        // ✅ withOpacity deprecate bo‘lsa: withAlpha ishlatamiz (0.12 * 255 ≈ 31)
        final badgeBg = iconColor.withAlpha(31);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(iconData, color: iconColor, size: 32),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: iconColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _formatDate(doc.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  switch (value) {
                    case "open":
                      _openDocument(doc);
                      break;
                    case "rename":
                      _renameDocumentByKey(box, key, doc);
                      break;
                    case "share":
                      _shareDocument(doc);
                      break;
                    case "delete":
                      await _confirmAndDeleteByKey(box, key, doc);
                      break;
                  }
                },
                itemBuilder:
                    (context) => const [
                      PopupMenuItem(
                        value: "open",
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new),
                            SizedBox(width: 8),
                            Text("Ochish"),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: "rename",
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text("Qayta nomlash"),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: "share",
                        child: Row(
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 8),
                            Text("Ulashish"),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: "delete",
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text("O‘chirish"),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================
  void _openDocument(DocumentModel doc) {
    OpenFile.open(doc.filePath);
  }

  Future<void> _shareDocument(DocumentModel doc) async {
    await Share.shareXFiles([XFile(doc.filePath)], text: "📄 ${doc.title}");
  }

  Future<void> _confirmAndDeleteByKey(
    Box<DocumentModel> box,
    dynamic key,
    DocumentModel doc,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("O‘chirish"),
            content: Text("“${doc.title}” hujjatini o‘chirmoqchimisiz?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Bekor qilish"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("O‘chirish"),
              ),
            ],
          ),
    );

    if (!mounted) return;
    if (ok != true) return;

    final file = File(doc.filePath);
    if (await file.exists()) {
      await file.delete();
    }

    await box.delete(key);
  }

  void _renameDocumentByKey(
    Box<DocumentModel> box,
    dynamic key,
    DocumentModel doc,
  ) {
    final ctrl = TextEditingController(text: doc.title);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Qayta nomlash"),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) async {
              await _saveRename(box, key, ctrl.text);
              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Bekor qilish"),
            ),
            TextButton(
              onPressed: () async {
                await _saveRename(box, key, ctrl.text);
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text("Saqlash"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveRename(
    Box<DocumentModel> box,
    dynamic key,
    String newTitle,
  ) async {
    final t = newTitle.trim();
    if (t.isEmpty) return;

    final old = box.get(key);
    if (old == null) return;

    await box.put(key, old.copyWith(title: t));
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================
  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "$y-$m-$d  $hh:$mm";
  }
}
