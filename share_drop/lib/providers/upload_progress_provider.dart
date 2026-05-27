import 'package:flutter_riverpod/flutter_riverpod.dart';

// Menyimpan nilai progress upload global (0.0 sampai 1.0)
final uploadProgressProvider = StateProvider<double>((ref) => 0.0);
