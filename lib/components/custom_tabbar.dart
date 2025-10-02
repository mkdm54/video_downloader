import 'package:flutter/material.dart';
import 'package:video_downloader/screens/settings.dart';
import 'package:video_downloader/screens/video_downloader_app.dart';

class CustomTabbar extends StatefulWidget {
  const CustomTabbar({super.key});

  @override
  State<CustomTabbar> createState() => _CustomTabbarState();
}

class _CustomTabbarState extends State<CustomTabbar> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    Center(child: VideoDownloaderApp()),
    Center(child: Settings()),
  ];

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        color: Colors.deepPurple,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTabItem(Icons.home, "Home", 0),
            _buildTabItem(Icons.settings, "Settings", 1),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onTabSelected(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.amber : Colors.white70),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.amber : Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
