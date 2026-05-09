import 'package:flutter/material.dart';
import 'dart:io';
import '../theme.dart';
import '../server/http_server.dart';

class FileManagerScreen extends StatefulWidget {
  final LocalServer server;
  
  const FileManagerScreen({Key? key, required this.server}) : super(key: key);

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  bool _isImage(String path) => ['.jpg', '.jpeg', '.png', '.gif', '.webp'].any((ext) => path.toLowerCase().endsWith(ext));
  bool _isVideo(String path) => ['.mp4', '.mov', '.avi', '.mkv'].any((ext) => path.toLowerCase().endsWith(ext));
  bool _isAudio(String path) => ['.mp3', '.wav', '.m4a', '.ogg'].any((ext) => path.toLowerCase().endsWith(ext));

  IconData _getFileIcon(String path) {
    if (_isImage(path)) return Icons.image_rounded;
    if (_isVideo(path)) return Icons.movie_rounded;
    if (_isAudio(path)) return Icons.music_note_rounded;
    if (path.toLowerCase().endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _getFileColor(String path) {
    if (_isImage(path)) return Colors.teal;
    if (_isVideo(path)) return Colors.blue;
    if (_isAudio(path)) return Colors.orange;
    if (path.toLowerCase().endsWith('.pdf')) return Colors.red;
    return AppTheme.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        body: FadeTransition(
          opacity: CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'File Saya',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.search_rounded, size: 22),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Custom Tabs
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorPadding: const EdgeInsets.all(4),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Semua'),
                      Tab(text: 'Foto'),
                      Tab(text: 'Video'),
                      Tab(text: 'Musik'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Tab Content
                Expanded(
                  child: TabBarView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildFileGrid(widget.server.sharedFiles),
                      _buildFileGrid(widget.server.sharedFiles.where((f) => _isImage(f.path)).toList()),
                      _buildFileGrid(widget.server.sharedFiles.where((f) => _isVideo(f.path)).toList()),
                      _buildFileGrid(widget.server.sharedFiles.where((f) => _isAudio(f.path)).toList()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileGrid(List<File> files) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 20),
            Text('Tidak ada file', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Kirim file dari Beranda untuk melihatnya di sini', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.85,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final name = file.path.split('/').last;
        final size = '${(file.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB';
        final icon = _getFileIcon(file.path);
        final color = _getFileColor(file.path);

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 400 + (index * 80)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: child,
              ),
            );
          },
          child: _buildFileCard(icon, name, size, color),
        );
      },
    );
  }

  Widget _buildFileCard(IconData icon, String title, String subtitle, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 36, color: color),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
