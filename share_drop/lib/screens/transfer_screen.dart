import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../server/http_server.dart';

class TransferScreen extends StatefulWidget {
  final LocalServer server;
  final String serverAddress;

  const TransferScreen({Key? key, required this.server, this.serverAddress = ''}) : super(key: key);

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  bool _isPicking = false;

  @override
  Widget build(BuildContext context) {
    final files = widget.server.sharedFiles;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildConnectionCard(),
              _buildPickArea(),
              _buildSectionHeader('Antrian Kirim', 'Hapus semua'),
              _buildQueueList(files),
              if (files.isNotEmpty) _buildSendButton(files.length),
              const SizedBox(height: 100),
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
          Text('Transfer Langsung', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w400)),
          const SizedBox(height: 4),
          Text('Kirim File', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 26)),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KONEKSI', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500, letterSpacing: 0.08)),
              Row(
                children: [
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('Terhubung', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.accentGreen)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _deviceItem(Icons.smartphone_rounded, 'iPhone Andi', 'Perangkat ini', AppTheme.textPrimary),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.swap_horiz_rounded, color: AppTheme.textSecondary, size: 20),
              ),
              _deviceItem(Icons.laptop_rounded, 'PC Browser', 'Tujuan', AppTheme.accentBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deviceItem(IconData icon, String name, String sub, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            Text(sub, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildPickArea() {
    return GestureDetector(
      onTap: _pickFiles,
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 14, 24, 0),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: CustomPaint(
          painter: DashRectPainter(color: Colors.black.withOpacity(0.12), strokeWidth: 2, gap: 4),
          child: Column(
            children: [
              Icon(Icons.add_to_photos_rounded, color: AppTheme.textSecondary.withOpacity(0.4), size: 36),
              const SizedBox(height: 10),
              Text('Tambah File', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text('Ketuk untuk memilih dari galeri atau penyimpanan', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
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
          GestureDetector(
            onTap: () => setState(() => widget.server.sharedFiles.clear()),
            child: Text(link, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(List<File> files) {
    if (files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Antrian kosong', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return _buildQueueItem(file);
      },
    );
  }

  Widget _buildQueueItem(File file) {
    final name = file.path.split('/').last;
    final iconData = _getFileIconInfo(file.path);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05)))),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: iconData.bgColor, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Icon(iconData.icon, color: iconData.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.08), borderRadius: BorderRadius.circular(2)),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 100, // Placeholder for 100%
                          decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Selesai', style: GoogleFonts.syne(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 18),
        ],
      ),
    );
  }

  Widget _buildSendButton(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(18)),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Kirim Semua ($count file)', style: GoogleFonts.syne(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  _IconInfo _getFileIconInfo(String path) {
    final lower = path.toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].any((e) => lower.endsWith(e))) {
      return _IconInfo(Icons.photo_rounded, const Color(0xFFD84040), const Color(0xFFFDEAEA));
    }
    if (['.mp4', '.mov', '.avi', '.mkv'].any((e) => lower.endsWith(e))) {
      return _IconInfo(Icons.movie_rounded, const Color(0xFF3B82F6), const Color(0xFFEAF0FD));
    }
    if (['.pdf', '.zip', '.rar', '.7z'].any((e) => lower.endsWith(e))) {
      return _IconInfo(Icons.folder_zip_rounded, const Color(0xFF8B5CF6), const Color(0xFFF0EAFD));
    }
    return _IconInfo(Icons.insert_drive_file_rounded, AppTheme.textSecondary, const Color(0xFFF0F0F0));
  }

  Future<void> _pickFiles() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    bool hasPermission = false;
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isGranted) {
        hasPermission = true;
      } else {
        final photos = await Permission.photos.request();
        final videos = await Permission.videos.request();
        final audio  = await Permission.audio.request();
        final storage = await Permission.storage.request();
        hasPermission = photos.isGranted || videos.isGranted || audio.isGranted || storage.isGranted;
      }
    } else { hasPermission = true; }

    if (!hasPermission) {
      setState(() => _isPicking = false);
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null && mounted) {
        for (final pf in result.files) {
          if (pf.path != null) {
            widget.server.addFile(File(pf.path!));
          }
        }
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error picking: $e');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }
}

class _IconInfo {
  final IconData icon;
  final Color color;
  final Color bgColor;
  _IconInfo(this.icon, this.color, this.bgColor);
}

class DashRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashRectPainter({this.color = Colors.black, this.strokeWidth = 1.0, this.gap = 5.0});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    Path path = Path();
    path.addRRect(RRect.fromLTRBR(0, 0, size.width, size.height, const Radius.circular(20)));

    Path dashPath = Path();
    double distance = 0.0;
    for (PathMetric measurePath in path.computeMetrics()) {
      while (distance < measurePath.length) {
        dashPath.addPath(measurePath.extractPath(distance, distance + gap), Offset.zero);
        distance += gap * 2;
      }
      distance = 0.0;
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(DashRectPainter oldDelegate) => false;
}
