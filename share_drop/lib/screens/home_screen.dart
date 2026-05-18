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
  late AnimationController _orbitController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  // Gunakan langsung dari server, bukan local list
  List<File> get _sharedFiles => widget.server.sharedFiles;

  @override
  void initState() {
    super.initState();

    _orbitController = AnimationController(duration: const Duration(seconds: 10), vsync: this)..repeat();

    _pulseController = AnimationController(duration: const Duration(milliseconds: 1800), vsync: this)
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _fadeController = AnimationController(duration: const Duration(milliseconds: 900), vsync: this)..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ──────────────────────────── QR Dialog ──────────────────────────────────
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
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 40, spreadRadius: 4)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                child: const Text('Scan QR Code',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 6),
              Text('Buka di browser PC',
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
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
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('URL disalin!')));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(12)),
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
                  style: TextButton.styleFrom(foregroundColor: Colors.white54),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────── File Picker ────────────────────────────────
  Future<void> _pickAndShareFile() async {
    bool hasPermission = false;
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isGranted) {
        hasPermission = true;
      } else {
        final results = await Future.wait([
          Permission.photos.request(),
          Permission.videos.request(),
          Permission.audio.request(),
          Permission.storage.request(),
        ]);
        hasPermission = results.any((s) => s.isGranted);
      }
    } else {
      hasPermission = true;
    }

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Izin akses file diperlukan.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null && mounted) {
        int added = 0;
        for (final pf in result.files) {
          if (pf.path != null) {
            widget.server.addFile(File(pf.path!));
            added++;
          }
        }
        setState(() {}); // Refresh tampilan karena server.sharedFiles berubah
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$added file ditambahkan ke daftar kirim'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  // ──────────────────────────── Helpers ────────────────────────────────────
  IconData _getFileIcon(String path) {
    final l = path.toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].any((e) => l.endsWith(e))) return Icons.image_rounded;
    if (['.mp4', '.mov', '.avi', '.mkv'].any((e) => l.endsWith(e))) return Icons.movie_rounded;
    if (['.mp3', '.wav', '.m4a', '.ogg'].any((e) => l.endsWith(e))) return Icons.music_note_rounded;
    if (['.pdf'].any((e) => l.endsWith(e))) return Icons.picture_as_pdf_rounded;
    if (['.zip', '.rar', '.7z'].any((e) => l.endsWith(e))) return Icons.folder_zip_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _getFileColor(String path) {
    final l = path.toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].any((e) => l.endsWith(e))) return const Color(0xFFFF7043);
    if (['.mp4', '.mov', '.avi', '.mkv'].any((e) => l.endsWith(e))) return const Color(0xFF7C4DFF);
    if (['.mp3', '.wav', '.m4a', '.ogg'].any((e) => l.endsWith(e))) return const Color(0xFF00E5FF);
    if (['.pdf'].any((e) => l.endsWith(e))) return const Color(0xFFFF1744);
    return AppTheme.primaryColor;
  }

  String _formatSize(int bytes) {
    if (bytes > 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes > 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  double _totalSizeMB() {
    return _sharedFiles.fold(0.0, (s, f) {
      try { return s + f.lengthSync() / 1024 / 1024; } catch (_) { return s; }
    });
  }

  // ──────────────────────────── BUILD ──────────────────────────────────────
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
            SliverToBoxAdapter(child: _buildStatsRow()),
            SliverToBoxAdapter(child: _buildRecentSection()),
            SliverToBoxAdapter(child: _buildConnectedSection()),
            SliverToBoxAdapter(child: _buildServerCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────── HERO ───────────────────────────────────────
  Widget _buildHeroHeader() {
    return SliverToBoxAdapter(
      child: Container(
        height: 320,
        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        child: Stack(
          children: [
            Positioned(top: -60, right: -40, child: _glowOrb(200, AppTheme.primaryColor.withOpacity(0.18))),
            Positioned(bottom: -40, left: -60, child: _glowOrb(180, AppTheme.accentColor.withOpacity(0.12))),
            Center(
              child: AnimatedBuilder(
                animation: _orbitController,
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    _orbitRing(155, _orbitController.value * 2 * pi, 1.0),
                    _orbitRing(105, -_orbitController.value * 2 * pi + pi / 3, 0.6),
                    _orbitRing(58, _orbitController.value * 2 * pi + pi, 0.35),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Selamat Datang di',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                            ShaderMask(
                              shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                              child: const Text('Pubel',
                                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: _showQRDialog,
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Center(
                      child: ScaleTransition(
                        scale: _pulseAnimation,
                        child: GestureDetector(
                          onTap: _pickAndShareFile,
                          child: Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: AppTheme.primaryColor.withOpacity(0.55), blurRadius: 26, spreadRadius: 4)
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_rounded, color: Colors.white, size: 30),
                                Text('Tambah', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 7, height: 7,
                                decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle)),
                            const SizedBox(width: 7),
                            Text(widget.serverAddress,
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
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
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.13 * opacity), width: 1),
            ),
          ),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationZ(angle),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(opacity),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.8 * opacity), blurRadius: 6)],
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
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }

  // ──────────────────────────── STATS ROW ──────────────────────────────────
  Widget _buildStatsRow() {
    final totalMB = _totalSizeMB();
    final connected = widget.server.connectedCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          _statCard(
            '${_sharedFiles.length}',
            'File Dibagikan',
            Icons.share_rounded,
            AppTheme.primaryGradient,
          ),
          const SizedBox(width: 10),
          _statCard(
            totalMB < 1 ? '${(totalMB * 1024).toStringAsFixed(0)} KB' : '${totalMB.toStringAsFixed(1)} MB',
            'Total Ukuran',
            Icons.storage_rounded,
            AppTheme.accentGradient,
          ),
          const SizedBox(width: 10),
          _statCard(
            '$connected',
            'Terhubung',
            Icons.devices_rounded,
            const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF00E676)]),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, LinearGradient gradient) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            Text(label,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────── RECENT FILES ───────────────────────────────
  Widget _buildRecentSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Riwayat File',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              if (_sharedFiles.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => widget.server.sharedFiles.clear()),
                  child: Text('Hapus Semua',
                      style: TextStyle(color: AppTheme.primaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _sharedFiles.isEmpty
              ? _emptyCard(Icons.history_rounded, 'Belum ada file dibagikan',
                  'Tekan tombol + untuk menambah file')
              : SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _sharedFiles.length,
                    itemBuilder: (context, index) {
                      // Show newest first
                      final file = _sharedFiles[_sharedFiles.length - 1 - index];
                      return _recentCard(file);
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _recentCard(File file) {
    final name = file.path.split('/').last;
    String size = '';
    try {
      size = _formatSize(file.lengthSync());
    } catch (_) {}
    final color = _getFileColor(file.path);
    return Container(
      width: 96,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(_getFileIcon(file.path), color: color, size: 20),
          ),
          const SizedBox(height: 7),
          Text(name,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(size, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 8)),
        ],
      ),
    );
  }

  // ──────────────────────────── CONNECTED DEVICES ──────────────────────────
  Widget _buildConnectedSection() {
    final ips = widget.server.connectedIps.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Perangkat Terhubung',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ips.isEmpty
              ? _emptyCard(Icons.devices_rounded, 'Belum ada perangkat terhubung',
                  'Buka URL server dari browser PC')
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _connectedDevice(ips[i], i + 1),
                ),
        ],
      ),
    );
  }

  Widget _connectedDevice(String ip, int index) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.laptop_mac_rounded, color: AppTheme.accentGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Perangkat $index',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(ip, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(width: 5, height: 5,
                    decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('Aktif', style: TextStyle(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────── SERVER CARD ────────────────────────────────
  Widget _buildServerCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1A1040), Color(0xFF111327)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.12), blurRadius: 20)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.computer_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Akses dari Browser PC',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(widget.serverAddress,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_2_rounded, color: AppTheme.primaryLight, size: 26),
              onPressed: _showQRDialog,
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────── HELPERS ────────────────────────────────────
  Widget _emptyCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.18), size: 32),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
        ],
      ),
    );
  }
}
