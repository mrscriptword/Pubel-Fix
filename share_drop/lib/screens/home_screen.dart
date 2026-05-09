import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../theme.dart';
import '../server/http_server.dart';

class HomeScreen extends StatelessWidget {
  final String serverAddress;
  final LocalServer server;
  
  const HomeScreen({Key? key, required this.server, this.serverAddress = 'Menunggu IP...'}) : super(key: key);

  Future<void> _pickAndShareFile(BuildContext context) async {
    // 1. Request Permission
    var status = await Permission.storage.request();
    if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izin penyimpanan diperlukan untuk berbagi file')),
      );
      return;
    }

    // 2. Pick File
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      server.addFile(file);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File ${result.files.single.name} siap diakses dari PC!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Purple Section
            Container(
              padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 40),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Selamat datang 👋',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      Row(
                        children: const [
                          Icon(Icons.search, color: Colors.white),
                          SizedBox(width: 16),
                          Icon(Icons.more_vert, color: Colors.white),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pubel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Send Button
                  GestureDetector(
                    onTap: () => _pickAndShareFile(context),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ]
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share, color: AppTheme.primaryColor, size: 32),
                          const SizedBox(height: 4),
                          const Text('Kirim', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ketuk untuk mulai berbagi',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Akses PC: $serverAddress',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Recently Shared
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TERAKHIR DIBAGIKAN',
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildRecentItem(Icons.image, 'Foto_012', '2.2 MB'),
                      _buildRecentItem(Icons.music_note, 'Lagu.mp3', '5.1 MB'),
                      _buildRecentItem(Icons.insert_drive_file, 'Laporan', '1.4 MB'),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Nearby Devices
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PERANGKAT TERDEKAT',
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildDeviceItem('A', 'Andika\'s Phone', 'Sejauhnya - Android'),
                  const SizedBox(height: 16),
                  _buildDeviceItem('R', 'Rina\'s iPhone', 'Sejauhnya - iOS', isGreen: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItem(IconData icon, String title, String size) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppTheme.textPrimary),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          Text(size, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(String initial, String name, String subtitle, {bool isGreen = false}) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: isGreen ? Colors.teal : AppTheme.primaryColor,
          child: Text(initial, style: const TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Hubung', style: TextStyle(color: Colors.white)),
        )
      ],
    );
  }
}
