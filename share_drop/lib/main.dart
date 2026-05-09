import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/file_manager_screen.dart';
import 'widgets/bottom_nav_bar.dart';
import 'server/http_server.dart';

void main() {
  runApp(const PubelApp());
}

class PubelApp extends StatelessWidget {
  const PubelApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pubel',
      theme: AppTheme.lightTheme,
      home: const MainNavigation(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final LocalServer _server = LocalServer();
  String _serverAddress = 'Memulai Server...';

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    final address = await _server.start();
    if (mounted) {
      setState(() {
        _serverAddress = address ?? 'Gagal mendapatkan IP';
      });
    }
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _buildScreen(),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(key: const ValueKey(0), server: _server, serverAddress: _serverAddress);
      case 1:
        return TransferScreen(key: const ValueKey(1), server: _server, serverAddress: _serverAddress);
      case 2:
        return FileManagerScreen(key: const ValueKey(2), server: _server);
      default:
        return HomeScreen(key: const ValueKey(0), server: _server, serverAddress: _serverAddress);
    }
  }
}
