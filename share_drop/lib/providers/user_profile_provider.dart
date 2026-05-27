import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';

final userProfileProvider = Provider<UserProfile>((ref) {
  return UserProfile(
    deviceId: 'pubel-1234',
    deviceName: 'Pubel Preview',
    deviceSub: 'Demo Mode',
  );
});
