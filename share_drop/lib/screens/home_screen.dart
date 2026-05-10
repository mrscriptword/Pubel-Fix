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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<File> _recentFiles = [];
  late AnimationController _orbitController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _showQRDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                child: const Text('Scan QR Code', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 6),
              Text('Buka di browser PC', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: widget.serverAddress,
                  version: QrVersions.auto,
                  size: 200.0,
                  foregroundColor: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.serverAddress));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL disalin!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 8),
                      Text(widget.serverAddress,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndShareFile() async {
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
    } else {
      hasPermission = true;
    }

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Izin akses file diperlukan.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.files.length} file ditambahkan'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  IconData _getFileIcon(String path) {
    final lower = path.toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].any((e) => lower.endsWith(e))) return Icons.image_rounded;
    if (['.mp4', '.mov', '.avi', '.mkv'].any((e) => lower.endsWith(e))) return Icons.movie_rounded;
    if (['.mp3', '.wav', '.m4a', '.ogg'].any((e) => lower.endsWith(e))) return Icons.music_note_rounded;
    if (['.pdf'].any((e) => lower.endsWith(e))) return Icons.picture_as_pdf_rounded;
    if (['.zip', '.rar', '.7z'].any((e) => lower.endsWith(e))) return Icons.folder_zip_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _getFileColor(String path) {
    final lower = path.toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].any((e) => lower.endsWith(e))) return const Color(0xFFFF7043);
    if (['.mp4', '.mov', '.avi', '.mkv'].any((e) => lower.endsWith(e))) return const Color(0xFF7C4DFF);
    if (['.mp3', '.wav', '.m4a', '.ogg'].any((e) => lower.endsWith(e))) return const Color(0xFF00E5FF);
    if (['.pdf'].any((e) => lower.endsWith(e))) return const Color(0xFFFF1744);
    return AppTheme.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColorDark,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeroHeader(),
            SliverToBoxAdapter(child: _buildQuickStats()),
            SliverToBoxAdapter(child: _buildRecentSection()),
            SliverToBoxAdapter(child: _buildServerCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────── HERO ────────────────────────────────
  Widget _buildHeroHeader() {
    return SliverToBoxAdapter(
      child: Container(
        height: 340,
        decoration: const BoxDecoration(
          gradient: AppTheme.heroGradient,
        ),
        child: Stack(
          children: [
            // Ambient orbs
            Positioned(top: -60, right: -40,
              child: _glowOrb(200, AppTheme.primaryColor.withOpacity(0.2))),
            Positioned(bottom: -40, left: -60,
              child: _glowOrb(180, AppTheme.accentColor.withOpacity(0.15))),

            // Orbit rings
            Center(
              child: AnimatedBuilder(
                animation: _orbitController,
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    _orbitRing(160, _orbitController.value * 2 * pi, 1.0),
                    _orbitRing(110, -_orbitController.value * 2 * pi + pi / 4, 0.7),
                    _orbitRing(64, _orbitController.value * 2 * pi + pi / 2, 0.4),
                  ],
                ),
              ),
            ),

            // Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Selamat Datang di',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                            ShaderMask(
                              shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                              child: const Text('Pubel',
                                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 22),
                          ),
                          onPressed: _showQRDialog,
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Center share button
                    Center(
                      child: ScaleTransition(
                        scale: _pulseAnimation,
                        child: GestureDetector(
                          onTap: _pickAndShareFile,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: AppTheme.primaryColor.withOpacity(0.6), blurRadius: 28, spreadRadius: 4),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_rounded, color: Colors.white, size: 30),
                                Text('Tambah', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Server address chip
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7, height: 7,
                              decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(widget.serverAddress,
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orbitRing(double size, double angle, double opacity) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.15 * opacity),
                width: 1,
              ),
            ),
          ),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationZ(angle),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(opacity),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.8 * opacity),
                      blurRadius: 6,
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }

  // ─────────────────────────── QUICK STATS ─────────────────────────────────
  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          _statCard('${_recentFiles.length}', 'File Dibagikan', Icons.share_rounded, AppTheme.primaryGradient),
          const SizedBox(width: 12),
          _statCard(
            _recentFiles.isEmpty ? '0 MB' : '${(_recentFiles.fold(0.0, (s, f) { try { return s + f.lengthSync() / 1024 / 1024; } catch (_) { return s; } })).toStringAsFixed(1)} MB',
            'Total Ukuran',
            Icons.storage_rounded,
            AppTheme.accentGradient,
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, LinearGradient gradient) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── RECENT FILES ────────────────────────────────
  Widget _buildRecentSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Terakhir Dibagikan',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              if (_recentFiles.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _recentFiles.clear()),
                  child: Text('Hapus Semua',
                      style: TextStyle(color: AppTheme.primaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _recentFiles.isEmpty
              ? _buildEmptyRecent()
              : SizedBox(
                  height: 130,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _recentFiles.length,
                    itemBuilder: (context, index) {
                      final file = _recentFiles[index];
                      return _recentCard(file);
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyRecent() {
    return Container(
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, color: Colors.white.withOpacity(0.2), size: 28),
          const SizedBox(height: 6),
          Text('Belum ada file dibagikan',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _recentCard(File file) {
    final name = file.path.split('/').last;
    String size = '';
    try {
      final bytes = file.lengthSync();
      size = bytes > 1048576 ? '${(bytes / 1048576).toStringAsFixed(1)} MB' : '${(bytes / 1024).toStringAsFixed(0)} KB';
    } catch (_) {}
    final color = _getFileColor(file.path);
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.12), blurRadius: 12),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getFileIcon(file.path), color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(size, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9)),
        ],
      ),
    );
  }

  // ─────────────────────────── SERVER CARD ─────────────────────────────────
  Widget _buildServerCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1040), Color(0xFF111327)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: AppTheme.primaryColor.withOpacity(0.15), blurRadius: 20),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.computer_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Akses dari Browser PC',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(widget.serverAddress,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_2_rounded, color: AppTheme.primaryLight, size: 28),
              onPressed: _showQRDialog,
            ),
          ],
        ),
      ),
    );
  }
}
