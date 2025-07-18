import 'package:autospaxe/screens/status/status.dart';
import 'package:flutter/material.dart';
import 'Home/home_screen.dart'; // Import HomeScreen
import 'profile/profile.dart';
import 'bookmarks/bookmark.dart';

class Bottomnav extends StatefulWidget {
  final String? userMail;

  const Bottomnav({super.key, this.userMail});

  @override
  State<Bottomnav> createState() => _BottomnavState();
}

class _BottomnavState extends State<Bottomnav> {
  int _currentIndex = 0;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(userMail: widget.userMail),
      CountdownPage(),
      //Bookmarker(),
      //Profile(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          margin: const EdgeInsets.only(bottom: 16, left: 9, right: 9),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 39, 38, 38),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 49, 48, 48).withOpacity(1.0),
                spreadRadius: 1,
                blurRadius: 7,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                isSelected: _currentIndex == 0,
                onTap: () => _onItemTapped(0),
              ),
              _buildNavItem(
                icon: Icons.map_outlined,
                isSelected: _currentIndex == 1,
                onTap: () => _onItemTapped(1),
              ),
              _buildNavItem(
                icon: Icons.bookmark_outline,
                isSelected: _currentIndex == 2,
                onTap: () => _onItemTapped(2),
              ),
              _buildNavItem(
                icon: Icons.person_2_outlined,
                isSelected: _currentIndex == 3,
                onTap: () => _onItemTapped(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    double iconSize = 30.0,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.blue : Colors.white,
            size: iconSize,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
