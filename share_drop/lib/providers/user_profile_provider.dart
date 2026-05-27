import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';

class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier() : super(
    UserProfile(
      deviceId: 'pubel-1234',
      deviceName: 'Pubel Preview',
      deviceSub: 'Demo Mode',
    )
  );

  void updateDeviceName(String newName) {
    state = UserProfile(
      deviceId: state.deviceId,
      deviceName: newName,
      deviceSub: state.deviceSub,
    );
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier();
});
