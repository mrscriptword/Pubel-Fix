import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import '../theme.dart';
import '../server/http_server.dart';
import 'package:permission_handler/permission_handler.dart';

class FileManagerScreen extends StatefulWidget {
  final LocalServer server;

  const FileManagerScreen({Key? key, required this.server}) : super(key: key);

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<FileSystemEntity> _allFiles     = [];
  List<FileSystemEntity> _imageFiles   = [];
  List<FileSystemEntity> _videoFiles   = [];
  List<FileSystemEntity> _audioFiles   = [];

  bool _isLoading = true;
  String _loadError = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ─────────── FAST LOADING: scan only top-level dirs (non-recursive) ──────
  Future<void> _loadFiles() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _loadError = ''; });

    bool hasPermission = false;
    if (Platform.isAndroid) {
      hasPermission = await Permission.manageExternalStorage.isGranted;
      if (!hasPermission) {
        hasPermission = await Permission.storage.isGranted ||
            await Permission.photos.isGranted ||
            await Permission.videos.isGranted ||
            await Permission.audio.isGranted;
      }
    } else {
      hasPermission = true;
    }

    if (!hasPermission) {
      if (mounted) setState(() { _isLoading = false; _loadError = 'Izin akses file belum diberikan.'; });
      return;
    }

    try {
      // Scan top-level dirs in parallel for speed
      final root = Directory('/storage/emulated/0');
      if (!await root.exists()) {
        if (mounted) setState(() { _isLoading = false; _loadError = 'Storage tidak ditemukan.'; });
        return;
      }

      final topDirs = [
        'DCIM', 'Pictures', 'Movies', 'Music', 'Downloads',
        'Documents', 'WhatsApp', 'Telegram', 'Android/media',
      ];

      final List<FileSystemEntity> all = [];

      // Use Future.wait for parallel scanning
      await Future.wait(topDirs.map((dir) async {
        final d = Directory('/storage/emulated/0/$dir');
        if (!await d.exists()) return;
        try {
          await for (final entity in d.list(recursive: true)) {
            if (entity is File) all.add(entity);
          }
        } catch (_) {
          // Skip dirs we can't access
        }
      }));

      if (!mounted) return;

      final imgs   = all.where((f) => _isImage(f.path)).toList();
      final vids   = all.where((f) => _isVideo(f.path)).toList();
      final audios = all.where((f) => _isAudio(f.path)).toList();

      setState(() {
        _allFiles   = all;
        _imageFiles = imgs;
        _videoFiles = vids;
        _audioFiles = audios;
        _isLoading  = false;
      });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _loadError = 'Gagal memuat file: $e'; });
    }
  }

  bool _isImage(String p) => ['.jpg', '.jpeg', '.png', '.gif', '.webp'].any((e) => p.toLowerCase().endsWith(e));
  bool _isVideo(String p) => ['.mp4', '.mov', '.avi', '.mkv'].any((e) => p.toLowerCase().endsWith(e));
  bool _isAudio(String p) => ['.mp3', '.wav', '.m4a', '.ogg'].any((e) => p.toLowerCase().endsWith(e));

  List<FileSystemEntity> _filter(List<FileSystemEntity> files) {
    if (_searchQuery.isEmpty) return files;
    return files.where((f) => f.path.split('/').last.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColorDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            const SizedBox(height: 4),
            Expanded(
              child: _isLoading
                  ? _buildLoading()
                  : _loadError.isNotEmpty
                      ? _buildError()
                      : TabBarView(
                          controller: _tabController,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildGrid(_filter(_allFiles),   Icons.insert_drive_file_rounded, AppTheme.primaryColor),
                            _buildGrid(_filter(_imageFiles),  Icons.image_rounded,             const Color(0xFFFF7043)),
                            _buildGrid(_filter(_videoFiles),  Icons.movie_rounded,             const Color(0xFF7C4DFF)),
                            _buildGrid(_filter(_audioFiles),  Icons.music_note_rounded,        const Color(0xFF00E5FF)),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────── HEADER ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          if (!_isSearching) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                    child: const Text('File Saya',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                  ),
                  Text(
                    _isLoading ? 'Memuat...' : '${_allFiles.length} file ditemukan',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                ],
              ),
            ),
            _iconBtn(Icons.search_rounded, () => setState(() => _isSearching = true)),
            const SizedBox(width: 8),
            _iconBtn(Icons.refresh_rounded, _loadFiles),
          ] else ...[
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: AppTheme.primaryLight, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Cari file...',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() { _isSearching = false; _searchQuery = ''; _searchController.clear(); }),
                      child: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
      ),
    );
  }

  // ─────────────────── TAB BAR ──────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        indicator: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: AppTheme.primaryColor.withOpacity(0.5), blurRadius: 12),
          ],
        ),
        indicatorPadding: const EdgeInsets.all(3),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Semua'),
          Tab(text: 'Foto'),
          Tab(text: 'Video'),
          Tab(text: 'Musik'),
        ],
      ),
    );
  }

  // ─────────────────── GRID ─────────────────────────────────────────────────
  Widget _buildGrid(List<FileSystemEntity> files, IconData defaultIcon, Color color) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(defaultIcon, size: 48, color: color.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('Tidak ada file', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.82),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index] as File;
        final name = file.path.split('/').last;
        int bytes = 0;
        try { bytes = file.lengthSync(); } catch (_) {}
        final size = bytes > 1048576 ? '${(bytes / 1048576).toStringAsFixed(1)}MB' : '${(bytes / 1024).toStringAsFixed(0)}KB';
        return _buildCard(defaultIcon, color, name, size, file);
      },
    );
  }

  Widget _buildCard(IconData icon, Color color, String name, String size, File file) {
    return GestureDetector(
      onTap: () => _shareFile(file),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 26, color: color),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 2),
            Text(size, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.35))),
          ],
        ),
      ),
    );
  }

  void _shareFile(File file) {
    widget.server.addFile(file);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${file.path.split('/').last} ditambahkan ke daftar kirim'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─────────────────── LOADING / ERROR ─────────────────────────────────────
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 16),
          Text('Memuat file...', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          const SizedBox(height: 4),
          Text('Harap tunggu sebentar', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 56, color: Colors.red.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('Akses Ditolak', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_loadError, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, height: 1.6)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                await openAppSettings();
                await Future.delayed(const Duration(seconds: 2));
                _loadFiles();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('Buka Pengaturan Izin',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
