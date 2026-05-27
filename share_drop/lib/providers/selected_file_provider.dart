import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';

// Menyimpan file yang sedang dipilih (misal: untuk detail view atau actions)
final selectedFileProvider = StateProvider<FileItem?>((ref) => null);
