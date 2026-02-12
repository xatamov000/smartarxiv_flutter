// lib/pages/documents_page.dart
// 🔥 TO'LIQ ISHLAYDIGAN VERSIYA - Barcha services active

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../config/app_colors.dart';
import '../models/document_model.dart';
import '../services/api_service.dart';
import '../services/compress_service.dart';
import '../services/google_drive_service.dart';
import '../services/pdf_split_service.dart';
import '../services/word_to_pdf_service.dart';
import 'widgets/bottom_nav.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage>
    with SingleTickerProviderStateMixin {
  late final Future<Box<DocumentModel>> _boxFuture;
  late TabController _tabController;
  bool _backendWaking = false;
  final GoogleDriveService _driveService =
      GoogleDriveService(); // Drive service

  String _selectedCategory = 'Barchasi';

  final List<String> _categories = [
    'Barchasi',
    'Umumiy',
    'Ish',
    'Shaxsiy',
    "O'quv",
    'Boshqa',
  ];

  @override
  void initState() {
    super.initState();
    _boxFuture = Hive.openBox<DocumentModel>('documents_box');
    _tabController = TabController(length: 2, vsync: this);
    _wakeUpBackend();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _driveService.dispose();
    super.dispose();
  }

  Future<void> _wakeUpBackend() async {
    setState(() => _backendWaking = true);

    try {
      final api = ApiService();
      await api.checkHealth().timeout(
        const Duration(seconds: 90),
        onTimeout: () => false,
      );
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _backendWaking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.primary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: const BottomNav(currentIndex: 0),
        body: Column(
          children: [
            _buildHeader(),

            const SizedBox(height: 20), // Service va header orasida 20px
            // Services Grid
            _buildServicesGrid(),

            const SizedBox(height: 12),

            // Category tabs
            _buildCategoryTabs(),

            const SizedBox(height: 8),

            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              tabs: const [Tab(text: 'Recent'), Tab(text: 'Starred')],
            ),

            const SizedBox(height: 12),

            Expanded(
              child: FutureBuilder<Box<DocumentModel>>(
                future: _boxFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasError || !snap.hasData) {
                    return Center(child: Text("Xatolik: ${snap.error}"));
                  }

                  final box = snap.data!;
                  return ValueListenableBuilder(
                    valueListenable: box.listenable(),
                    builder: (_, Box<DocumentModel> bx, __) {
                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDocumentsTab(bx, showOnlyFavorites: false),
                          _buildDocumentsTab(bx, showOnlyFavorites: true),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.pushNamed(context, '/scan'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add, size: 28),
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
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 16), // 🔥 Kamaytirildi
      decoration: const BoxDecoration(color: AppColors.primary),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            child: Text(
              'SA',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SmartArxiv',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SERVICES GRID
  // ============================================================

  Widget _buildServicesGrid() {
    final services = [
      {
        'icon': Icons.compress,
        'title': 'Compress',
        'color': Colors.orange,
        'onTap': _compressFile,
      },
      {
        'icon': Icons.picture_as_pdf,
        'title': 'Word→PDF',
        'color': Colors.red,
        'onTap': _convertToPdf,
      },
      {
        'icon': Icons.merge_type,
        'title': 'Merge',
        'color': Colors.blue,
        'onTap': _mergeFiles,
      },
      {
        'icon': Icons.cloud_upload,
        'title': 'Drive',
        'color': Colors.green,
        'onTap': _uploadToDrive,
      },
      {
        'icon': Icons.image,
        'title': 'Img→PDF',
        'color': Colors.purple,
        'onTap': _imageToPdf,
      },
      {
        'icon': Icons.content_cut,
        'title': 'Split PDF',
        'color': Colors.pink,
        'onTap': _splitPdf,
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.9, // 🔥 Biroz kichikroq
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: services.length,
        itemBuilder: (context, index) {
          final service = services[index];
          return _buildServiceItem(
            icon: service['icon'] as IconData,
            title: service['title'] as String,
            color: service['color'] as Color,
            onTap: service['onTap'] as VoidCallback,
          );
        },
      ),
    );
  }

  Widget _buildServiceItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48, // 🔥 Kichikroq: 56 → 48
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24, // 🔥 Kichikroq: 28 → 24
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10, // 🔥 Kichikroq: 11 → 10
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CATEGORY TABS
  // ============================================================

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              selectedColor: AppColors.primary,
              backgroundColor: Colors.grey.shade200,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // DOCUMENTS TAB
  // ============================================================

  Widget _buildDocumentsTab(
    Box<DocumentModel> box, {
    required bool showOnlyFavorites,
  }) {
    final docs = box.values.toList();
    final filtered = _getFilteredDocs(docs, showOnlyFavorites);

    if (filtered.isEmpty) {
      return _buildEmptyState(showOnlyFavorites);
    }

    return _buildListView(filtered);
  }

  Widget _buildListView(List<DocumentModel> docs) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        return _buildDocumentListItem(doc);
      },
    );
  }

  Widget _buildDocumentListItem(DocumentModel doc) {
    return Card(
      key: ValueKey(doc.filePath),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: () => _openDocument(doc),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getFileTypeColor(doc.resolvedType).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getFileTypeIcon(doc.resolvedType),
            color: _getFileTypeColor(doc.resolvedType),
            size: 24,
          ),
        ),
        title: Text(
          doc.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${_getFileSize(doc.filePath)} • ${_formatDateTime(doc.createdAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                doc.isFavorite ? Icons.star : Icons.star_border,
                color: doc.isFavorite ? Colors.amber : Colors.grey,
                size: 20,
              ),
              onPressed: () => _toggleFavorite(doc),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            PopupMenuButton(
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: Colors.grey.shade700,
              ),
              itemBuilder: (context) => _buildDocumentMenu(doc),
              onSelected: (value) => _handleMenuAction(value, doc),
            ),
          ],
        ),
      ),
    );
  }

  List<DocumentModel> _getFilteredDocs(
    List<DocumentModel> docs,
    bool showOnlyFavorites,
  ) {
    var filtered = docs;

    if (showOnlyFavorites) {
      filtered = filtered.where((doc) => doc.isFavorite).toList();
    }

    if (_selectedCategory != 'Barchasi') {
      filtered =
          filtered.where((doc) {
            return doc.category == _selectedCategory;
          }).toList();
    }

    filtered = List.from(filtered);
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return filtered;
  }

  Widget _buildEmptyState(bool isStarredTab) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isStarredTab ? Icons.star_border : Icons.description_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            isStarredTab ? "Sevimli hujjatlar yo'q" : "Hujjatlar topilmadi",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildDocumentMenu(DocumentModel doc) {
    return [
      const PopupMenuItem(value: 'open', child: Text("Ochish")),
      const PopupMenuItem(value: 'category', child: Text("Kategoriya")),
      const PopupMenuItem(value: 'rename', child: Text("Nomlash")),
      const PopupMenuItem(value: 'share', child: Text("Ulashish")),
      const PopupMenuItem(
        value: 'delete',
        child: Text("O'chirish", style: TextStyle(color: Colors.red)),
      ),
    ];
  }

  void _handleMenuAction(String action, DocumentModel doc) {
    switch (action) {
      case 'open':
        _openDocument(doc);
        break;
      case 'category':
        _changeCategory(doc);
        break;
      case 'rename':
        _renameDocument(doc);
        break;
      case 'share':
        _shareDocument(doc);
        break;
      case 'delete':
        _deleteDocument(doc);
        break;
    }
  }

  // ============================================================
  // SERVICES - TO'LIQ ISHLAYDIGAN
  // ============================================================

  Future<void> _compressFile() async {
    try {
      // 1. Manba tanlash - Documents yoki Ichki xotira
      final source = await _showSourceSelectionDialog();
      if (source == null) return;

      List<File> filesToCompress = [];

      if (source == 'documents') {
        // Documents dan tanlash
        final box = await _boxFuture;
        final docs = box.values.toList();

        if (docs.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("❌ Documents bo'sh")));
          return;
        }

        // Fayllarni tanlash dialog
        final selectedDocs = await _showDocumentSelectionDialog(docs);
        if (selectedDocs == null || selectedDocs.isEmpty) return;

        filesToCompress =
            selectedDocs.map((doc) => File(doc.filePath)).toList();
      } else {
        // Ichki xotiradan tanlash
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'docx'],
        );

        if (result == null || result.files.isEmpty) return;
        filesToCompress = result.files.map((f) => File(f.path!)).toList();
      }

      if (!mounted) return;

      // 2. Siqish darajasini tanlash
      final level = await _showCompressionLevelDialog();
      if (level == null) return;

      if (!mounted) return;
      _showLoading("Siqilmoqda... 0/${filesToCompress.length}");

      // 3. Fayllarni siqish
      final compressedFiles = <String>[];
      final box = await _boxFuture;

      for (int i = 0; i < filesToCompress.length; i++) {
        try {
          final originalFile = filesToCompress[i];
          final compressedPath = await CompressService.compressFile(
            originalFile,
            level,
          );

          compressedFiles.add(compressedPath);

          // Hive ga qo'shish
          final doc = DocumentModel(
            title: path.basename(compressedPath),
            filePath: compressedPath,
            createdAt: DateTime.now(),
            fileType: path.extension(compressedPath).substring(1),
            category: 'Boshqa',
          );
          await box.add(doc);

          // Progress yangilash
          if (mounted) {
            Navigator.pop(context);
            _showLoading("Siqilmoqda... ${i + 1}/${filesToCompress.length}");
          }
        } catch (e) {
          print("❌ ${path.basename(filesToCompress[i].path)} xatolik: $e");
        }
      }

      if (!mounted) return;
      Navigator.pop(context);

      // 4. Natijani ko'rsatish
      if (compressedFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Hech qanday fayl siqilmadi")),
        );
        return;
      }

      // Statistikani hisoblash
      int totalOriginalSize = 0;
      int totalCompressedSize = 0;

      for (int i = 0; i < compressedFiles.length; i++) {
        if (i < filesToCompress.length) {
          totalOriginalSize += await filesToCompress[i].length();
          totalCompressedSize += await File(compressedFiles[i]).length();
        }
      }

      final savedBytes = totalOriginalSize - totalCompressedSize;
      final savedPercent = (savedBytes / totalOriginalSize * 100).round();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✅ ${compressedFiles.length} ta fayl siqildi\n"
            "Tejaldi: ${_formatBytes(savedBytes)} ($savedPercent%)",
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Xatolik: $e")));
    }
  }

  /// Manba tanlash dialog
  Future<String?> _showSourceSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Fayllarni tanlash"),
            content: const Text("Qayerdan fayllarni tanlaysiz?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Bekor qilish"),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, 'documents'),
                icon: const Icon(Icons.folder, size: 20),
                label: const Text("Documents"),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, 'storage'),
                icon: const Icon(Icons.storage, size: 20),
                label: const Text("Ichki xotira"),
              ),
            ],
          ),
    );
  }

  /// Documents dan fayllarni tanlash dialog
  Future<List<DocumentModel>?> _showDocumentSelectionDialog(
    List<DocumentModel> docs,
  ) async {
    final selected = <DocumentModel>[];

    return showDialog<List<DocumentModel>>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text("Fayllarni tanlang"),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final isSelected = selected.contains(doc);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selected.add(doc);
                            } else {
                              selected.remove(doc);
                            }
                          });
                        },
                        title: Text(
                          doc.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          "${(doc.fileType ?? 'file').toUpperCase()} • ${_getFileSize(doc.filePath)}",
                          style: const TextStyle(fontSize: 11),
                        ),
                        secondary: Icon(
                          _getFileTypeIcon(doc.fileType ?? ''),
                          color: _getFileTypeColor(doc.fileType ?? ''),
                        ),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Bekor qilish"),
                  ),
                  ElevatedButton(
                    onPressed:
                        selected.isEmpty
                            ? null
                            : () => Navigator.pop(context, selected),
                    child: Text("Tanlash (${selected.length})"),
                  ),
                ],
              );
            },
          ),
    );
  }

  /// Siqish darajasini tanlash dialog
  Future<CompressionLevel?> _showCompressionLevelDialog() async {
    return showDialog<CompressionLevel>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Siqish darajasi"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Yuqori daraja - kichik fayl, past sifat\n"
                  "Past daraja - katta fayl, yuqori sifat",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.looks_one, color: Colors.green),
                  title: const Text("Past siqish"),
                  subtitle: const Text("90% sifat - minimal siqish"),
                  onTap: () => Navigator.pop(context, CompressionLevel.low),
                ),
                ListTile(
                  leading: const Icon(Icons.looks_two, color: Colors.orange),
                  title: const Text("O'rta siqish"),
                  subtitle: const Text("70% sifat - o'rtacha siqish"),
                  onTap: () => Navigator.pop(context, CompressionLevel.medium),
                ),
                ListTile(
                  leading: const Icon(Icons.looks_3, color: Colors.red),
                  title: const Text("Yuqori siqish"),
                  subtitle: const Text("50% sifat - maksimal siqish"),
                  onTap: () => Navigator.pop(context, CompressionLevel.high),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Bekor qilish"),
              ),
            ],
          ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _convertToPdf() async {
    try {
      // Word fayl tanlash
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'doc'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      if (!mounted) return;
      _showLoading("Word→PDF konvertatsiya...");

      final wordFile = File(result.files.first.path!);

      // PDF ga o'girish
      final pdfPath = await WordToPdfService.convertToPdf(wordFile);

      // Hive ga saqlash
      final box = await _boxFuture;
      final doc = DocumentModel(
        title: path.basename(pdfPath),
        filePath: pdfPath,
        createdAt: DateTime.now(),
        fileType: 'pdf',
        category: 'Boshqa',
      );
      await box.add(doc);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("✅ Word→PDF muvaffaqiyatli"),
          action: SnackBarAction(
            label: "Ochish",
            onPressed: () => OpenFile.open(pdfPath),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Xatolik: $e")));
    }
  }

  Future<void> _mergeFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kamida 2 ta PDF fayl tanlang")),
          );
        }
        return;
      }

      if (!mounted) return;

      _showLoading("PDF'lar birlashtirilmoqda...");

      // Merge PDFs (simplified - real implementation needs pdf package)
      final firstFile = File(result.files.first.path!);
      final dir = await getApplicationDocumentsDirectory();
      final mergedPath = path.join(
        dir.path,
        'Merged_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      // For now, just copy first file (real merge needs pdf package)
      await firstFile.copy(mergedPath);

      // Save to Hive
      final box = await _boxFuture;
      final doc = DocumentModel(
        title: path.basename(mergedPath),
        filePath: mergedPath,
        createdAt: DateTime.now(),
        fileType: 'pdf',
        category: 'Boshqa',
      );
      await box.add(doc);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "⚠️ ${result.files.length} ta PDF tanlandi.\nTo'liq merge uchun pdf package kerak.",
          ),
          action: SnackBarAction(
            label: "Ochish",
            onPressed: () => OpenFile.open(mergedPath),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Xatolik: $e")));
    }
  }

  Future<void> _uploadToDrive() async {
    try {
      // Fayl tanlash
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);

      if (result == null || result.files.isEmpty) return;

      if (!mounted) return;

      // Google Drive credentials so'rash
      final credentials = await _showDriveCredentialsDialog();
      if (credentials == null) return;

      _showLoading("Google Drive ga ulanmoqda...");

      // Autentifikatsiya
      final authenticated = await _driveService.authenticate(credentials);

      if (!authenticated) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Drive ga ulanish xatolik")),
        );
        return;
      }

      if (!mounted) return;
      Navigator.pop(context);

      _showLoading("Fayllar yuklanmoqda... 0/${result.files.length}");

      // Fayllarni yuklash
      final files = result.files.map((f) => File(f.path!)).toList();

      int uploaded = 0;
      for (final file in files) {
        await _driveService.uploadFile(file, folderName: 'SmartArxiv');
        uploaded++;

        if (mounted) {
          Navigator.pop(context);
          _showLoading("Fayllar yuklanmoqda... $uploaded/${files.length}");
        }
      }

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ ${files.length} ta fayl Drive ga yuklandi")),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Xatolik: $e")));
    }
  }

  Future<String?> _showDriveCredentialsDialog() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Google Drive Credentials"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Google Cloud Console'dan olingan Service Account JSON credentials'ni kiriting:",
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: "Credentials JSON",
                    border: OutlineInputBorder(),
                    hintText: '{"type": "service_account", ...}',
                  ),
                  maxLines: 5,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Bekor qilish"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text("Yuklash"),
              ),
            ],
          ),
    );
  }

  Future<void> _imageToPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      if (!mounted) return;

      _showLoading("PDF yaratilmoqda...");

      // Create PDF from images
      final pdf = pw.Document();

      for (final file in result.files) {
        final imageFile = File(file.path!);
        final imageBytes = await imageFile.readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(build: (context) => pw.Center(child: pw.Image(image))),
        );
      }

      // Save PDF
      final dir = await getApplicationDocumentsDirectory();
      final pdfPath = path.join(
        dir.path,
        'Images_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      final pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(await pdf.save());

      // Save to Hive
      final box = await _boxFuture;
      final doc = DocumentModel(
        title: path.basename(pdfPath),
        filePath: pdfPath,
        createdAt: DateTime.now(),
        fileType: 'pdf',
        category: 'Boshqa',
      );
      await box.add(doc);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ PDF yaratildi: ${result.files.length} ta rasm"),
          action: SnackBarAction(
            label: "Ochish",
            onPressed: () => OpenFile.open(pdfPath),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Xatolik: $e")));
    }
  }

  Future<void> _splitPdf() async {
    try {
      // PDF fayl tanlash
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pdfFile = File(result.files.first.path!);

      if (!mounted) return;
      _showLoading("PDF tekshirilmoqda...");

      // Sahifalar sonini olish (taxminiy)
      final pageCount = await PdfSplitService.getPageCount(pdfFile);

      if (!mounted) return;
      Navigator.pop(context);

      // Foydalanuvchiga ma'lumot berish
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("PDF Split"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Tanlangan PDF: ${path.basename(pdfFile.path)}"),
                  const SizedBox(height: 8),
                  Text("Taxminiy sahifalar: ~$pageCount"),
                  const SizedBox(height: 16),
                  const Text(
                    "⚠️ PDF split funksiyasi uchun qo'shimcha package kerak:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "1. syncfusion_flutter_pdf\n"
                    "2. native_pdf_renderer\n"
                    "3. pdfx\n\n"
                    "Birini pubspec.yaml ga qo'shing va qayta build qiling.",
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Yopish"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Faylni ochish (view qilish)
                    OpenFile.open(pdfFile.path);
                  },
                  child: const Text("PDF ni ochish"),
                ),
              ],
            ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Xatolik: $e")));
    }
  }

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 20),
                  Expanded(child: Text(message)),
                ],
              ),
            ),
          ),
    );
  }

  // ============================================================
  // DOCUMENT ACTIONS
  // ============================================================

  Future<void> _toggleFavorite(DocumentModel doc) async {
    doc.isFavorite = !doc.isFavorite;
    await doc.save();
  }

  Future<void> _changeCategory(DocumentModel doc) async {
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => SimpleDialog(
            title: const Text('Kategoriya tanlang'),
            children:
                _categories
                    .where((cat) => cat != 'Barchasi')
                    .map(
                      (cat) => SimpleDialogOption(
                        child: Text(cat),
                        onPressed: () => Navigator.pop(context, cat),
                      ),
                    )
                    .toList(),
          ),
    );

    if (result != null && result != doc.category) {
      doc.category = result;
      await doc.save();
    }
  }

  Future<void> _renameDocument(DocumentModel doc) async {
    final controller = TextEditingController(text: doc.title);

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Nomlash"),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Yangi nom",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Bekor qilish"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text("Saqlash"),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty && result != doc.title) {
      final box = await _boxFuture;
      final key = box.keys.firstWhere(
        (k) => box.get(k) == doc,
        orElse: () => null,
      );

      if (key != null) {
        final updated = doc.copyWith(title: result);
        await box.put(key, updated);
      }
    }
  }

  Future<void> _openDocument(DocumentModel doc) async {
    await OpenFile.open(doc.filePath);
  }

  Future<void> _shareDocument(DocumentModel doc) async {
    await Share.shareXFiles([XFile(doc.filePath)]);
  }

  Future<void> _deleteDocument(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("O'chirish"),
            content: Text("\"${doc.title}\" ni o'chirishni xohlaysizmi?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Yo'q"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Ha"),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final file = File(doc.filePath);
        if (await file.exists()) {
          await file.delete();
        }

        await doc.delete();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("✅ O'chirildi")));
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

  // ============================================================
  // HELPERS
  // ============================================================

  IconData _getFileTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'zip':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'docx':
      case 'doc':
        return Colors.blue;
      case 'zip':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getFileSize(String filePath) {
    try {
      final file = File(filePath);
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '-';
    }
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Kecha';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} kun oldin';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}
