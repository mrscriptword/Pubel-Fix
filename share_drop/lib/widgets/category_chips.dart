import 'package:flutter/material.dart';

class CategoryChips extends StatefulWidget {
  final Function(String) onSelected;

  const CategoryChips({Key? key, required this.onSelected}) : super(key: key);

  @override
  _CategoryChipsState createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<CategoryChips> {
  int _activeIndex = 0;
  final categories = [
    {'label': 'Semua', 'icon': Icons.layers_outlined},
    {'label': 'Gambar', 'icon': Icons.image_outlined},
    {'label': 'Video', 'icon': Icons.movie_outlined},
    {'label': 'Dokumen', 'icon': Icons.description_outlined},
    {'label': 'Musik', 'icon': Icons.music_note_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isActive = _activeIndex == index;
          final theme = Theme.of(context);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                children: [
                  Icon(
                    cat['icon'] as IconData, 
                    size: 14, 
                    color: isActive ? theme.colorScheme.onPrimary : theme.textTheme.bodyLarge?.color
                  ),
                  const SizedBox(width: 6),
                  Text(cat['label'] as String),
                ],
              ),
              selected: isActive,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _activeIndex = index);
                  widget.onSelected(cat['label'] as String);
                }
              },
              backgroundColor: theme.colorScheme.surface,
              selectedColor: theme.textTheme.bodyLarge?.color,
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                color: isActive ? theme.colorScheme.onPrimary : theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
                side: BorderSide(
                  color: isActive ? Colors.transparent : theme.dividerColor,
                  width: 1.5,
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }
}
