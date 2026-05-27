import 'package:flutter/material.dart';

class MobileUploadCard extends StatelessWidget {
  final VoidCallback onTap;

  const MobileUploadCard({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1814),
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Decorative circles mimicking the CSS ::before and ::after
            Positioned(
              top: -40, right: -40,
              child: Container(
                width: 160, height: 160,
                decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
              ),
            ),
            Positioned(
              bottom: -60, left: 20,
              child: Container(
                width: 200, height: 200,
                decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
              ),
            ),
            
            // Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, size: 12, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        'Transfer Cepat',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Seret atau pilih\nfile manapun',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Wi-Fi Direct · tanpa kuota internet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 16, color: Color(0xFF1A1814)),
                      const SizedBox(width: 8),
                      Text(
                        'Pilih File',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF1A1814),
                          fontWeight: FontWeight.w600, 
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
