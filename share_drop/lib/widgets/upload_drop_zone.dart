import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

class UploadDropZone extends StatefulWidget {
  final VoidCallback onTap;

  const UploadDropZone({
    Key? key,
    required this.onTap,
  }) : super(key: key);

  @override
  _UploadDropZoneState createState() => _UploadDropZoneState();
}

class _UploadDropZoneState extends State<UploadDropZone> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = _isHovering ? theme.primaryColor : theme.dividerColor;
    final bgColor = _isHovering ? theme.primaryColor.withOpacity(0.05) : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            // Menggunakan border solid sebagai representasi sederhana. 
            // Untuk dashed border bisa menggunakan custom painter atau plugin 'dotted_border'
            border: Border.all(
              color: borderColor,
              width: 2,
              style: BorderStyle.solid, 
            ),
          ),
          child: Column(
            children: [
              AnimatedSlide(
                offset: _isHovering ? const Offset(0, -0.1) : Offset.zero,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 40,
                  color: _isHovering ? theme.primaryColor : theme.iconTheme.color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Seret file ke sini',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w300,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.iconTheme.color,
                  ),
                  children: [
                    const TextSpan(text: 'atau '),
                    TextSpan(
                      text: 'pilih dari komputer',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
