import 'package:flutter/material.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/app_topbar.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_screen_mobile.dart';
import 'transfer_screen.dart';
import 'file_manager_screen.dart';
import 'activity_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      // 📱 === TAMPILAN MOBILE ===
      mobileBody: Scaffold(
        body: _buildMobileBody(),
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
        ),
      ),
      
      // 💻 === TAMPILAN DESKTOP ===
      desktopBody: Scaffold(
        body: Row(
          children: [
            AppSidebar(
              selectedIndex: _currentIndex,
              sharedBadgeCount: 3, 
              onMenuSelected: _onTabSelected,
              onCategorySelected: (cat) {
                debugPrint("Filter kategori desktop: $cat");
              },
            ),
            Expanded(
              child: Column(
                children: [
                  const AppTopbar(title: 'File Sharing'),
                  Expanded(
                    child: _buildDesktopBody(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Router untuk konten Mobile
  Widget _buildMobileBody() {
    switch (_currentIndex) {
      case 0: return const HomeScreenMobile();
      case 1: return const TransferScreen();
      case 2: return const FileManagerScreen();
      case 3: return const ActivityScreen();
      default: return const HomeScreenMobile();
    }
  }

  // Router untuk konten Desktop
  // Desktop Sidebar memiliki urutan index: 0 (Beranda), 1 (File Explorer), 2 (Dikirim/Aktivitas)
  Widget _buildDesktopBody() {
    switch (_currentIndex) {
      case 0: 
        return const Center(child: Text('Desktop Home Layout\n(Silakan rakit komponen UploadDropZone, StatCard, dll di sini)'));
      case 1: 
        return const FileManagerScreen();
      case 2: 
        return const ActivityScreen();
      default: 
        return const SizedBox.shrink();
    }
  }
}
