import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
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
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showQRDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Scan QR Code', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Akses server dari browser PC dengan scan kode ini', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: QrImageView(
                  data: widget.serverAddress,
                  version: QrVersions.auto,
                  size: 200.0,
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(widget.serverAddress, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Tutup'),
                ),
              )
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin diperlukan.')));
      }
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        widget.server.addFile(file);
        setState(() {
          _recentFiles.insert(0, file);
          if (_recentFiles.length > 10) _recentFiles.removeLast();
        });
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
    return Icons.insert_drive_file_rounded;
  }

  List<File> _getFilteredFiles() {
    if (_searchQuery.isEmpty) return _recentFiles;
    return _recentFiles.where((f) => f.path.split('/').last.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFiles = _getFilteredFiles();

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section
              Container(
                padding: const EdgeInsets.only(top: 56, left: 24, right: 24, bottom: 40),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!_isSearching)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Selamat datang 👋', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              SizedBox(height: 4),
                              Text('Pubel', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                            ],
                          )
                        else
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Cari riwayat file...',
                                hintStyle: const TextStyle(color: Colors.white54),
                                border: InputBorder.none,
                                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white70),
                                  onPressed: () {
                                    setState(() {
                                      _isSearching = false;
                                      _searchQuery = '';
                                      _searchController.clear();
                                    });
                                  },
                                ),
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                          ),
                        if (!_isSearching)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.search, color: Colors.white),
                                onPressed: () => setState(() => _isSearching = true),
                              ),
                              IconButton(
                                icon: const Icon(Icons.qr_code_rounded, color: Colors.white),
                                onPressed: _showQRDialog,
                              ),
                            ],
                          )
                      ],
                    ),
                    const SizedBox(height: 36),
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: GestureDetector(
                        onTap: _pickAndShareFile,
                        child: Container(
                          width: 100, height: 100,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.share_rounded, color: AppTheme.primaryColor, size: 32),
                              const Text('Kirim', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(24)),
                      child: Text(widget.serverAddress, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(_isSearching ? 'Hasil Pencarian' : 'Terakhir Dibagikan', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              filteredFiles.isEmpty 
                ? _buildEmptyState(Icons.history_rounded, 'Tidak ada file', 'File tidak ditemukan atau belum ada riwayat')
                : SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: filteredFiles.length,
                      itemBuilder: (context, index) {
                        final file = filteredFiles[index];
                        return _buildRecentItem(_getFileIcon(file.path), file.path.split('/').last, '${(file.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB');
                      },
                    ),
                  ),
              const SizedBox(height: 28),
              _buildPCStatusCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 20),
          Icon(icon, size: 40, color: Colors.grey.shade300),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRecentItem(IconData icon, String title, String size) {
    return Container(
      width: 100, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: AppTheme.primaryColor),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          Text(size, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPCStatusCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppTheme.backgroundColorDark, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            const Icon(Icons.computer, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Akses dari PC Browser', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(widget.serverAddress, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_2, color: Colors.white70),
              onPressed: _showQRDialog,
            )
          ],
        ),
      ),
    );
  }
}
