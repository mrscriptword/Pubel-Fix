import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../theme.dart';
import '../server/http_server.dart';

class TransferScreen extends StatefulWidget {
  final LocalServer server;
  final String serverAddress;

  const TransferScreen({Key? key, required this.server, this.serverAddress = ''}) : super(key: key);

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _fadeController;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _fadeController.dispose();
    super.dispose();
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
    } else {
      hasPermission = true;
    }

    if (!hasPermission) {
      setState(() => _isPicking = false);
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
      if (result != null && mounted) {
        int added = 0;
        for (final pf in result.files) {
          if (pf.path != null) {
            widget.server.addFile(File(pf.path!));
            added++;
          }
        }
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$added file ditambahkan ke daftar kirim'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking: $e');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _removeFile(int index) {
    setState(() => widget.server.sharedFiles.removeAt(index));
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

  String _formatSize(int bytes) {
    if (bytes > 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes > 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColorDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: ShaderMask(
            shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
            child: const Text('Transfer File',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
          ),
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Kirim (ke PC)', icon: Icon(Icons.upload_rounded)),
              Tab(text: 'Terima (dari PC)', icon: Icon(Icons.download_rounded)),
            ],
          ),
        ),
        body: FadeTransition(
          opacity: CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
          child: TabBarView(
            children: [
              _buildSendTab(),
              _buildReceiveTab(),
            ],
          ),
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Widget _buildSendTab() {
    final files = widget.server.sharedFiles;
    return Column(
      children: [
        _buildTopBar(files),
        Expanded(
          child: files.isEmpty ? _buildEmptyState('Kirim') : _buildFileList(files, false),
        ),
      ],
    );
  }

  Widget _buildReceiveTab() {
    return StreamBuilder<File>(
      stream: widget.server.onFileReceived,
      builder: (context, snapshot) {
        final files = widget.server.receivedFiles;
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Text(
                files.isEmpty ? 'Belum ada file diterima' : '${files.length} file diterima',
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13),
              ),
            ),
            Expanded(
              child: files.isEmpty ? _buildEmptyState('Terima') : _buildFileList(files, true),
            ),
          ],
        );
      }
    );
  }

  Widget _buildTopBar(List<File> files) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Text(
            files.isEmpty ? 'Pilih file untuk dikirim' : '${files.length} file siap dikirim',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13),
          ),
          const Spacer(),
          if (files.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => widget.server.sharedFiles.clear()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Text('Hapus Semua',
                    style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _radarController,
            builder: (context, _) {
              return SizedBox(
                height: 180,
                width: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildRing(180, _radarController.value),
                    _buildRing(130, (_radarController.value + 0.33) % 1.0),
                    _buildRing(80, (_radarController.value + 0.66) % 1.0),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: AppTheme.primaryColor.withOpacity(0.5), blurRadius: 20, spreadRadius: 3)
                        ],
                      ),
                      child: Icon(type == 'Kirim' ? Icons.send_rounded : Icons.download_rounded, color: Colors.white, size: 26),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          Text(type == 'Kirim' ? 'Belum ada file dipilih' : 'Belum ada file diterima',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            type == 'Kirim' 
              ? 'Tekan tombol + di bawah untuk memilih file
yang akan dibagikan ke PC'
              : 'File yang diupload dari PC akan muncul di sini',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, height: 1.6),
          ),
          if (widget.serverAddress.contains('http') && type == 'Kirim') ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_rounded, color: AppTheme.primaryLight, size: 18),
                  const SizedBox(width: 10),
                  Text(widget.serverAddress,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileList(List<File> files, bool isReceive) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: isReceive ? files.length : files.length + 1,
      itemBuilder: (context, index) {
        if (!isReceive && index == 0) return _buildServerStatusCard();
        
        final fileIndex = isReceive ? index : index - 1;
        final file = files[fileIndex];
        final name = file.path.split('/').last;
        int fileSize = 0;
        try { fileSize = file.lengthSync(); } catch (_) {}
        final color = _getFileColor(file.path);

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 350 + (fileIndex * 80)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (_, val, child) => Opacity(
            opacity: val,
            child: Transform.translate(offset: Offset(0, 18 * (1 - val)), child: child),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_getFileIcon(file.path), color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(width: 6, height: 6,
                                decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text(_formatSize(fileSize),
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                            Text(isReceive ? ' · Tersimpan' : ' · Siap diakses',
                                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isReceive)
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.3), size: 20),
                      onPressed: () => _removeFile(fileIndex),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildServerStatusCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1040), Color(0xFF111327)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _radarController,
            builder: (_, __) => Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.4 + 0.3 * _radarController.value),
                    blurRadius: 14,
                  )
                ],
              ),
              child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Server Aktif',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  widget.serverAddress.isNotEmpty ? widget.serverAddress : 'Menunggu IP...',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(width: 6, height: 6,
                    decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('Aktif', style: TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _isPicking ? null : _pickFiles,
      backgroundColor: Colors.transparent,
      elevation: 0,
      label: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: AppTheme.primaryColor.withOpacity(0.6), blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isPicking
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(_isPicking ? 'Memilih...' : 'Pilih File',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildRing(double size, double animValue) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.1 + (0.25 * (1 - animValue))),
          width: 1.5,
        ),
      ),
    );
  }
}
