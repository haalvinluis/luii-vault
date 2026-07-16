import 'package:flutter/material.dart';
import '../ui/reels/reels_page.dart';
import '../ui/gallery/gallery_page.dart';
import '../ui/music/music_page.dart';

class VaultRoutes {
  static const String reels = '/reels';
  static const String gallery = '/gallery';
  static const String music = '/music';

  static Map<String, WidgetBuilder> get routes {
    return {
      reels: (context) => const ReelsPage(),
      gallery: (context) => const GalleryPage(),
      music: (context) => const MusicPage(),
    };
  }
}
