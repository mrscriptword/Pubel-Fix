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

class _FileManagerScreenState extends State<FileManagerScreen> {
  final TextEditingController _searchController = TextEditingController();

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
              _buildSearchBar(),
              _buildStorageVisual(),
              _buildSectionHeader('Kategori Folder'),
              _buildFolderGrid(),
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
      child: Text('File Saya', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 26)),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari file atau folder...',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageVisual() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Penyimpanan Internal', style: GoogleFonts.syne(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('84% Terpakai', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
                ],
              ),
              const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text.rich(TextSpan(
            text: '108.4',
            style: GoogleFonts.syne(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1),
            children: [
              TextSpan(text: ' GB', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.w400)),
            ],
          )),
          const SizedBox(height: 10),
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.84,
              child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3))),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _storageCat(AppTheme.accentBlue, 'Media'),
              const SizedBox(width: 14),
              _storageCat(AppTheme.accentGreen, 'Dokumen'),
              const SizedBox(width: 14),
              _storageCat(AppTheme.textSecondary, 'Lainnya'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _storageCat(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.55))),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Text(title, style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
    );
  }

  Widget _buildFolderGrid() {
    final folders = [
      {'name': 'Kamera', 'icon': Icons.camera_alt_rounded, 'color': AppTheme.accentRed, 'count': '1,204', 'size': '4.2 GB'},
      {'name': 'WhatsApp', 'icon': Icons.message_rounded, 'color': AppTheme.accentGreen, 'count': '8,421', 'size': '12.8 GB'},
      {'name': 'Download', 'icon': Icons.download_rounded, 'color': AppTheme.accentBlue, 'count': '142', 'size': '2.1 GB'},
      {'name': 'Dokumen', 'icon': Icons.description_rounded, 'color': AppTheme.accentAmber, 'count': '52', 'size': '480 MB'},
    ];

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.1,
      ),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final f = folders[index];
        return _folderCard(f['name'] as String, f['icon'] as IconData, f['color'] as Color, f['count'] as String, f['size'] as String);
      },
    );
  }

  Widget _folderCard(String name, IconData icon, Color color, String count, String size) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(100)),
                child: Text(count, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const Spacer(),
          Text(name, style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          Text(size, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
}
