import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class VaultBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const VaultBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      height: 70,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0x20FFFFFF),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.movie_creation_outlined,
                  activeIcon: Icons.movie_creation,
                  label: "Reels",
                  index: 0,
                  activeColor: VaultTheme.neonCyan,
                ),
                _buildNavItem(
                  icon: Icons.photo_library_outlined,
                  activeIcon: Icons.photo_library,
                  label: "Gallery",
                  index: 1,
                  activeColor: VaultTheme.neonCyan,
                ),
                _buildNavItem(
                  icon: Icons.library_music_outlined,
                  activeIcon: Icons.library_music,
                  label: "Playlists",
                  index: 2,
                  activeColor: VaultTheme.electricViolet,
                ),
                _buildNavItem(
                  icon: Icons.headphones_outlined,
                  activeIcon: Icons.headphones,
                  label: "Player",
                  index: 3,
                  activeColor: VaultTheme.electricViolet,
                ),
                _buildNavItem(
                  icon: Icons.psychology_outlined,
                  activeIcon: Icons.psychology,
                  label: "Assistant",
                  index: 4,
                  activeColor: VaultTheme.hotPink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required Color activeColor,
  }) {
    final bool isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: Icon(
              isActive ? activeIcon : icon,
              color: isActive ? activeColor : VaultTheme.textMuted,
              size: 26,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : VaultTheme.textMuted,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              shadows: isActive
                  ? [
                      Shadow(
                        color: activeColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                      )
                    ]
                  : [],
            ),
          ),
        ],
      ),
    );
  }
}

