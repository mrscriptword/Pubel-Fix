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
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
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
    _searchController.dispose();
    super.dispose();
  }

  bool _isImage(String path) => ['.jpg', '.jpeg', '.png', '.gif', '.webp'].any((ext) => path.toLowerCase().endsWith(ext));
  bool _isVideo(String path) => ['.mp4', '.mov', '.avi', '.mkv'].any((ext) => path.toLowerCase().endsWith(ext));
  bool _isAudio(String path) => ['.mp3', '.wav', '.m4a', '.ogg'].any((ext) => path.toLowerCase().endsWith(ext));

  List<File> _filterFiles(List<File> files) {
    if (_searchQuery.isEmpty) return files;
    return files.where((f) => f.path.split('/').last.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
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
                      if (!_isSearching)
                        const Text('File Saya', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))
                      else
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Cari file...',
                              border: InputBorder.none,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.close),
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
                        IconButton(
                          icon: const Icon(Icons.search_rounded),
                          onPressed: () => setState(() => _isSearching = true),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
                  child: TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    indicator: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(12)),
                    indicatorPadding: const EdgeInsets.all(4),
                    tabs: const [Tab(text: 'Semua'), Tab(text: 'Foto'), Tab(text: 'Video'), Tab(text: 'Musik')],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildFileGrid(_filterFiles(widget.server.sharedFiles)),
                      _buildFileGrid(_filterFiles(widget.server.sharedFiles.where((f) => _isImage(f.path)).toList())),
                      _buildFileGrid(_filterFiles(widget.server.sharedFiles.where((f) => _isVideo(f.path)).toList())),
                      _buildFileGrid(_filterFiles(widget.server.sharedFiles.where((f) => _isAudio(f.path)).toList())),
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
      return Center(child: Text('Tidak ada file', style: TextStyle(color: Colors.grey.shade400)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.85),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final name = file.path.split('/').last;
        final size = '${(file.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB';
        return _buildFileCard(Icons.insert_drive_file, name, size);
      },
    );
  }

  Widget _buildFileCard(IconData icon, String title, String subtitle) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, size: 36, color: AppTheme.primaryColor)),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
