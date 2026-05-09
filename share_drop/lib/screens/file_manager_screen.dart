import 'package:flutter/material.dart';
import 'dart:io';
import '../theme.dart';
import '../server/http_server.dart';

class FileManagerScreen extends StatelessWidget {
  final LocalServer server;
  
  const FileManagerScreen({Key? key, required this.server}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        appBar: AppBar(
          title: const Text('File Saya', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          actions: const [
            Icon(Icons.search),
            SizedBox(width: 16),
          ],
          bottom: const TabBar(
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryColor,
            tabs: [
              Tab(text: 'Semua'),
              Tab(text: 'Foto'),
              Tab(text: 'Video'),
              Tab(text: 'Musik'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFileGrid(server.sharedFiles),
            _buildFileGrid(server.sharedFiles.where((f) => _isImage(f.path)).toList()),
            _buildFileGrid(server.sharedFiles.where((f) => _isVideo(f.path)).toList()),
            _buildFileGrid(server.sharedFiles.where((f) => _isAudio(f.path)).toList()),
          ],
        ),
      ),
    );
  }

  bool _isImage(String path) => ['.jpg', '.jpeg', '.png', '.gif', '.webp'].any((ext) => path.toLowerCase().endsWith(ext));
  bool _isVideo(String path) => ['.mp4', '.mov', '.avi', '.mkv'].any((ext) => path.toLowerCase().endsWith(ext));
  bool _isAudio(String path) => ['.mp3', '.wav', '.m4a', '.ogg'].any((ext) => path.toLowerCase().endsWith(ext));

  Widget _buildFileGrid(List<File> files) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('Tidak ada file ditemukan', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final name = file.path.split('/').last;
        final size = '${(file.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB';
        
        IconData icon = Icons.insert_drive_file;
        Color color = Colors.grey.shade100;

        if (_isImage(file.path)) {
          icon = Icons.image;
          color = Colors.teal.shade100;
        } else if (_isVideo(file.path)) {
          icon = Icons.movie;
          color = Colors.blue.shade100;
        } else if (_isAudio(file.path)) {
          icon = Icons.music_note;
          color = AppTheme.primaryColor.withOpacity(0.2);
        }

        return _buildFileCard(icon, name, size, color);
      },
    );
  }

  Widget _buildFileCard(IconData icon, String title, String subtitle, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ]
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 40, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
