import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'ui/navigation/bottom_nav.dart';
import 'ui/reels/reels_page.dart';
import 'ui/gallery/gallery_page.dart';
import 'ui/music/playlists_page.dart';
import 'ui/music/music_page.dart';
import 'ui/assistant/assistant_page.dart';
import 'ai/assistant_engine.dart';
import 'ui/assistant/assistant_widget.dart';

import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LUII VAULT',
      debugShowCheckedModeBanner: false,
      theme: VaultTheme.darkTheme,
      home: const VaultNavigationHost(),
    );
  }
}

class VaultNavigationHost extends StatefulWidget {
  const VaultNavigationHost({super.key});

  @override
  State<VaultNavigationHost> createState() => VaultNavigationHostState();
}

class VaultNavigationHostState extends State<VaultNavigationHost> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final List<Widget> _pages;
  final AssistantEngine _assistantEngine = AssistantEngine();
  bool _isBottomNavVisible = true;

  void setBottomNavVisible(bool visible) {
    if (_isBottomNavVisible != visible) {
      setState(() {
        _isBottomNavVisible = visible;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _pages = [
      const ReelsPage(),
      const GalleryPage(),
      PlaylistsPage(onTabSwitch: _setIndex),
      const MusicPage(),
      const AiAssistantPage(),
    ];

    _assistantEngine.onNavigateCallback = (page) {
      int idx = _currentIndex;
      if (page == "reels" || page == "home") idx = 0;
      if (page == "gallery") idx = 1;
      if (page == "playlists") idx = 2;
      if (page == "music") idx = 3;
      if (page == "assistant" || page == "ai assistant") idx = 4;
      _setIndex(idx);
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_assistantEngine.isVoiceWakeEnabled && _assistantEngine.isActive) {
        _assistantEngine.startWakeWordScan();
      }
    }
  }

  void _setIndex(int idx) {
    if (_currentIndex == idx) return;
    setState(() {
      _currentIndex = idx;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Pages stack
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          
          // Bottom glassmorphic navigation bar
          if (_isBottomNavVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VaultBottomNav(
                currentIndex: _currentIndex,
                onTap: _setIndex,
              ),
            ),
        ],
      ),
    );
  }
}
