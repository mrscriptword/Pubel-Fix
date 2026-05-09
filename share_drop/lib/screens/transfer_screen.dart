import 'package:flutter/material.dart';
import '../theme.dart';

class TransferScreen extends StatelessWidget {
  const TransferScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColorDark,
      appBar: AppBar(
        leading: const Icon(Icons.arrow_back),
        actions: const [
          Icon(Icons.more_vert),
          SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transfer ke Andika',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Terhubung via Wi-Fi Direct - 48 MB/s',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 40),
            
            // Radar Animation Placeholder
            Center(
              child: SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                      ),
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.6), width: 2),
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.smartphone, color: Colors.white),
                    ),
                    Positioned(
                      right: 20,
                      top: 40,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.teal,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ),
                    )
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            const Text('2 file • 11.3 MB', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            
            // File 1
            _buildFileTransferItem(Icons.camera_alt, 'Foto_012.jpg', '3.2 MB - JPEG', '78%'),
            const SizedBox(height: 16),
            // File 2
            _buildFileTransferItem(Icons.music_note, 'Lagu_Favorit.mp3', '8.1 MB - MP3', 'Antri'),
            
            const Spacer(),
            
            // Speed indicator
            Center(
              child: Column(
                children: const [
                  Text(
                    '48 MB/s',
                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Estimasi 12 detik lagi',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTransferItem(IconData icon, String title, String subtitle, String status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: status.contains('%') ? double.parse(status.replaceAll('%', '')) / 100 : 0.0,
                  backgroundColor: Colors.grey.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                )
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(status, style: TextStyle(color: status == 'Antri' ? Colors.grey : AppTheme.primaryColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
