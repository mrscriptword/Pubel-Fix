import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final bool hasFiles = widget.server.sharedFiles.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColorDark,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: hasFiles ? _buildActiveTransfer() : _buildEmptyState(),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTransfer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Sedang Berbagi',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.server.sharedFiles.length} file tersedia untuk diunduh via PC',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
        ),
        const SizedBox(height: 32),
        
        // Animated Radar
        Center(
          child: SizedBox(
            height: 180,
            width: 180,
            child: AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildAnimatedRing(180, _radarController.value),
                    _buildAnimatedRing(130, (_radarController.value + 0.3) % 1.0),
                    _buildAnimatedRing(80, (_radarController.value + 0.6) % 1.0),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 28),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        
        const SizedBox(height: 24),

        // IP Address card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor.withOpacity(0.2), AppTheme.accentColor.withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.language_rounded, color: AppTheme.primaryLight, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Alamat Akses PC', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      widget.serverAddress.isNotEmpty ? widget.serverAddress : 'Menunggu IP...',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text('Aktif', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Text(
          '${widget.server.sharedFiles.length} file • ${_calculateTotalSize()} MB',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: widget.server.sharedFiles.length,
            itemBuilder: (context, index) {
              final file = widget.server.sharedFiles[index];
              final name = file.path.split('/').last;
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 400 + (index * 100)),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildFileItem(Icons.insert_drive_file_rounded, name, 'Siap diakses'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated radar even when empty
          AnimatedBuilder(
            animation: _radarController,
            builder: (context, _) {
              return SizedBox(
                height: 160,
                width: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildAnimatedRing(160, _radarController.value),
                    _buildAnimatedRing(110, (_radarController.value + 0.4) % 1.0),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                      ),
                      child: Icon(Icons.cloud_off_outlined, color: Colors.grey.withOpacity(0.5), size: 24),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            'Tidak ada transfer aktif',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Klik "Kirim" di Beranda untuk memulai',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
          ),
          const SizedBox(height: 24),
          // Show IP Address even if empty
          if (widget.serverAddress.contains('http'))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_rounded, color: AppTheme.primaryLight, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    widget.serverAddress,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedRing(double size, double animValue) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.15 + (0.2 * (1 - animValue))),
          width: 1.5,
        ),
      ),
    );
  }

  String _calculateTotalSize() {
    double total = 0;
    for (var file in widget.server.sharedFiles) {
      try {
        total += file.lengthSync() / 1024 / 1024;
      } catch (_) {}
    }
    return total.toStringAsFixed(1);
  }

  Widget _buildFileItem(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryLight, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
        ],
      ),
    );
  }
}
