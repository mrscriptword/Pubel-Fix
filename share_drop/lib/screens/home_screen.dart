import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'dart:math';
import '../theme.dart';
import '../server/http_server.dart';

class HomeScreen extends StatefulWidget {
  final String serverAddress;
  final LocalServer server;

  const HomeScreen({Key? key, required this.server, this.serverAddress = 'Menunggu IP...'}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<File> _recentFiles = [];
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildUploadCard(),
              _buildStatsRow(),
              _buildSectionHeader('File Terbaru', 'Lihat semua'),
              _buildCategoryChips(),
              _buildRecentFilesList(),
              const SizedBox(height: 100), // Space for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selamat pagi, Andi 👋',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w400),
              ),
              Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Text('AN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Kirim &\nTerima File',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28, height: 1.1),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return GestureDetector(
      onTap: _pickAndShareFile,
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -40, right: -40,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              bottom: -60, left: 20,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), shape: BoxShape.circle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, color: Colors.white60, size: 12),
                        const SizedBox(width: 4),
                        Text('Transfer Cepat', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Seret atau pilih\nfile manapun', style: GoogleFonts.syne(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, height: 1.2)),
                  const SizedBox(height: 6),
                  Text('Wi-Fi Direct · tanpa kuota internet', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, color: AppTheme.primaryColor, size: 16),
                        const SizedBox(width: 8),
                        Text('Pilih File', style: GoogleFonts.syne(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          _miniStat(AppTheme.accentGreen.withOpacity(0.1), AppTheme.accentGreen, Icons.arrow_upward_rounded, '24', 'Dikirim'),
          const SizedBox(width: 12),
          _miniStat(AppTheme.accentBlue.withOpacity(0.1), AppTheme.accentBlue, Icons.arrow_downward_rounded, '9', 'Diterima'),
          const SizedBox(width: 12),
          _miniStat(AppTheme.accentAmber.withOpacity(0.1), AppTheme.accentAmber, Icons.database_rounded, '22G', 'Dipakai'),
        ],
      ),
    );
  }

  Widget _miniStat(Color bg, Color color, IconData icon, String val, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(height: 10),
            Text(val, style: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String link) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          Text(link, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = [
      {'label': 'Semua', 'icon': Icons.grid_view_rounded},
      {'label': 'Gambar', 'icon': Icons.photo_rounded},
      {'label': 'Video', 'icon': Icons.movie_rounded},
      {'label': 'Dokumen', 'icon': Icons.description_rounded},
      {'label': 'Musik', 'icon': Icons.music_note_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat['label'];
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat['label'] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: isSelected ? Colors.transparent : Colors.black.withOpacity(0.08), width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(cat['icon'] as IconData, size: 14, color: isSelected ? Colors.white : AppTheme.textPrimary),
                  const SizedBox(width: 6),
                  Text(cat['label'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isSelected ? Colors.white : AppTheme.textPrimary)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentFilesList() {
    if (_recentFiles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          height: 100,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_rounded, color: AppTheme.textSecondary.withOpacity(0.3), size: 28),
              const SizedBox(height: 6),
              Text('Belum ada file terbaru', style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5), fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentFiles.length,
      itemBuilder: (context, index) {
        final file = _recentFiles[index];
        return _buildFileItem(file);
      },
    );
  }

  Widget _buildFileItem(File file) {
    final name = file.path.split('/').last;
    final size = _getFileSize(file);
    final iconData = _getFileIconInfo(file.path);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: iconData.bgColor, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Icon(iconData.icon, color: iconData.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Tersimpan · Baru saja', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Text(size, style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  String _getFileSize(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes > 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    } catch (_) { return '--'; }
  }

  _IconInfo _getFileIconInfo(String path) {
    final lower = path.toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].any((e) => lower.endsWith(e))) {
      return _IconInfo(Icons.photo_rounded, const Color(0xFFD84040), const Color(0xFFFDEAEA));
    }
    if (['.mp4', '.mov', '.avi', '.mkv'].any((e) => lower.endsWith(e))) {
      return _IconInfo(Icons.movie_rounded, const Color(0xFF3B82F6), const Color(0xFFEAF0FD));
    }
    if (['.mp3', '.wav', '.m4a', '.ogg'].any((e) => lower.endsWith(e))) {
      return _IconInfo(Icons.music_note_rounded, const Color(0xFFF59E0B), const Color(0xFFFDF5E8));
    }
    if (['.pdf', '.doc', '.docx', '.txt'].any((e) => lower.endsWith(e))) {
      return _IconInfo(Icons.description_rounded, const Color(0xFF10B981), const Color(0xFFE8F5EE));
    }
    return _IconInfo(Icons.insert_drive_file_rounded, AppTheme.textSecondary, const Color(0xFFF0F0F0));
  }

  Future<void> _pickAndShareFile() async {
     // Reuse existing logic from original file
     bool hasPermission = false;
     if (Platform.isAndroid) {
       if (await Permission.manageExternalStorage.request().isGranted) {
         hasPermission = true;
       } else {
         final photos = await Permission.photos.request();
         final videos = await Permission.videos.request();
         final audio = await Permission.audio.request();
         final storage = await Permission.storage.request();
         hasPermission = photos.isGranted || videos.isGranted || audio.isGranted || storage.isGranted;
       }
     } else { hasPermission = true; }

     if (!hasPermission) return;

     try {
       FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
       if (result != null) {
         for (final pf in result.files) {
           if (pf.path != null) {
             final file = File(pf.path!);
             widget.server.addFile(file);
             setState(() {
               if (!_recentFiles.any((f) => f.path == file.path)) {
                 _recentFiles.insert(0, file);
                 if (_recentFiles.length > 15) _recentFiles.removeLast();
               }
             });
           }
         }
       }
     } catch (e) { debugPrint('Error picking file: $e'); }
  }
}

class _IconInfo {
  final IconData icon;
  final Color color;
  final Color bgColor;
  _IconInfo(this.icon, this.color, this.bgColor);
}
