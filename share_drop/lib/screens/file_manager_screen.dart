import 'package:flutter/material.dart';
import '../theme.dart';

class FileManagerScreen extends StatelessWidget {
  const FileManagerScreen({Key? key}) : super(key: key);

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
            _buildGridView(),
            const Center(child: Text('Foto')),
            const Center(child: Text('Video')),
            const Center(child: Text('Musik')),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.count(
      padding: const EdgeInsets.all(24),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: [
        _buildFileCard(Icons.camera_alt, 'Liburan_Bali.jpg', '4.1 MB • Foto', Colors.teal.shade100),
        _buildFileCard(Icons.movie, 'Vlog_jalan.mp4', '132 MB • Video', Colors.teal.shade200),
        _buildFileCard(Icons.description, 'Laporan_Q2.pdf', '2.2 MB • Dokumen', Colors.amber.shade100),
        _buildFileCard(Icons.music_note, 'Playlist_Gym.mp3', '24 MB • Musik', AppTheme.primaryColor.withOpacity(0.2)),
      ],
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
