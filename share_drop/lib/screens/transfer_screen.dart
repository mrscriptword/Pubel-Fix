import 'package:flutter/material.dart';
import '../theme.dart';
import '../server/http_server.dart';

class TransferScreen extends StatelessWidget {
  final LocalServer server;
  
  const TransferScreen({Key? key, required this.server}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isTransferring = server.sharedFiles.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColorDark,
      appBar: AppBar(
        title: const Text('Transfer'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: isTransferring 
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sedang Berbagi',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  '${server.sharedFiles.length} file tersedia untuk diunduh via PC',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 40),
                
                // Radar Animation Placeholder
                Center(
                  child: SizedBox(
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildRadarCircle(150, 0.2),
                        _buildRadarCircle(100, 0.4),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.wifi_tethering, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                Text('${server.sharedFiles.length} file • Total ${_calculateTotalSize()} MB', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                
                Expanded(
                  child: ListView.builder(
                    itemCount: server.sharedFiles.length,
                    itemBuilder: (context, index) {
                      final file = server.sharedFiles[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildFileTransferItem(
                          Icons.insert_drive_file, 
                          file.path.split('/').last, 
                          'Siap diakses', 
                          '100%'
                        ),
                      );
                    },
                  ),
                ),
                
                const Center(
                  child: Text(
                    'Server Aktif',
                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_outlined, size: 80, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 24),
                  const Text(
                    'Tidak ada transfer aktif',
                    style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Klik "Kirim" di halaman Beranda untuk mulai',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
      ),
    );
  }

  String _calculateTotalSize() {
    double total = 0;
    for (var file in server.sharedFiles) {
      total += file.lengthSync() / 1024 / 1024;
    }
    return total.toStringAsFixed(1);
  }

  Widget _buildRadarCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primaryColor.withOpacity(opacity), width: 2),
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
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(status, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
