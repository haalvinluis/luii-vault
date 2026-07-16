import '../models/reel_model.dart';
import '../models/photo_model.dart';
import '../models/music_model.dart';

class VaultConstants {
  static final List<ReelModel> mockReels = [
    ReelModel(
      id: "reel_1",
      creatorName: "cyber_ghost_😎",
      caption: "Neo-Tokyo rain vibes. Cyberpunk alleyway loading... 🌧️🌌 #neon #cyberpunk #vibes",
      likesCount: 1420,
      commentsCount: 89,
      tags: ["cyberpunk", "neon", "vibes", "tokyo"],
      visualType: "neon_matrix",
      audioFrequencyName: "Chill Lofi Synth - 432Hz",
    ),
    ReelModel(
      id: "reel_2",
      creatorName: "coder_homie_🔥",
      caption: "Hacking the mainframe. The grind never stops. Let's compile! 💻👾 #coding #matrix #dev",
      likesCount: 3822,
      commentsCount: 142,
      tags: ["coding", "matrix", "dev", "grind"],
      visualType: "binary_rain",
      audioFrequencyName: "Synthwave Hacking Beat - 120BPM",
    ),
    ReelModel(
      id: "reel_3",
      creatorName: "fitness_bro_💪",
      caption: "Push limits today fam! Gym pump is real! No excuses. 🏋️‍♂️🔥 #fitness #gym #beastmode",
      likesCount: 954,
      commentsCount: 34,
      tags: ["fitness", "gym", "beastmode", "hype"],
      visualType: "pulsing_energy",
      audioFrequencyName: "Electro Pump Hype Beat",
    ),
    ReelModel(
      id: "reel_4",
      creatorName: "zen_mindset_🧘",
      caption: "Close your eyes, breathe, and align your frequencies. 🧘‍♂️✨ #meditation #zen #peace",
      likesCount: 2200,
      commentsCount: 110,
      tags: ["meditation", "zen", "peace", "calm"],
      visualType: "sacred_geometry",
      audioFrequencyName: "Binaural Theta Soundscape - 6Hz",
    ),
  ];

  static final List<PhotoModel> mockPhotos = [
    PhotoModel(
      id: "photo_1",
      title: "Cyberpunk Sunset Skyline",
      category: "Vibes",
      tags: ["sunset", "neon", "cyberpunk", "vibes", "city"],
      aiConfidence: {
        "cyberpunk": 0.98,
        "sunset": 0.95,
        "neon": 0.92,
      },
      visualStyle: "neon_sunset",
      creationDate: "2026-07-01",
    ),
    PhotoModel(
      id: "photo_2",
      title: "Mainframe Server Setup",
      category: "Places",
      tags: ["office", "code", "neon", "desk", "servers"],
      aiConfidence: {
        "servers": 0.99,
        "neon": 0.90,
        "office": 0.85,
      },
      visualStyle: "server_room",
      creationDate: "2026-07-02",
    ),
    PhotoModel(
      id: "photo_3",
      title: "Developer Homie Meetup",
      category: "Faces",
      tags: ["friends", "night out", "smile", "party", "crew"],
      aiConfidence: {
        "friends": 0.94,
        "smile": 0.91,
        "party": 0.88,
      },
      visualStyle: "hologram_face",
      creationDate: "2026-07-04",
    ),
    PhotoModel(
      id: "photo_4",
      title: "Quantum Lab Concept",
      category: "Places",
      tags: ["lab", "science", "future", "laser"],
      aiConfidence: {
        "future": 0.97,
        "laser": 0.92,
        "lab": 0.89,
      },
      visualStyle: "quantum_grid",
      creationDate: "2026-07-05",
    ),
    PhotoModel(
      id: "photo_5",
      title: "Synthesizer Sound Board",
      category: "Vibes",
      tags: ["music", "synth", "knobs", "audio", "studio"],
      aiConfidence: {
        "synth": 0.96,
        "studio": 0.91,
        "music": 0.88,
      },
      visualStyle: "audio_knobs",
      creationDate: "2026-07-06",
    ),
    PhotoModel(
      id: "photo_6",
      title: "Solitary Neon Palm Tree",
      category: "Vibes",
      tags: ["sunset", "beach", "ocean", "neon", "palm"],
      aiConfidence: {
        "sunset": 0.99,
        "palm": 0.97,
        "beach": 0.92,
      },
      visualStyle: "neon_palm",
      creationDate: "2026-07-07",
    ),
  ];

  static final List<BinauralPreset> binauralPresets = [
    BinauralPreset(
      name: "Alpha Focus",
      leftFreq: 400,
      rightFreq: 410,
      description: "Creates a 10Hz Alpha beat. Optimal for deep focus, studying, and creative state. 🧠🔥",
      category: "Focus",
    ),
    BinauralPreset(
      name: "Theta Meditation",
      leftFreq: 200,
      rightFreq: 206,
      description: "Creates a 6Hz Theta beat. Perfect for deep meditation, inner peace, and vivid recall. 🧘‍♂️✨",
      category: "Meditation",
    ),
    BinauralPreset(
      name: "Gamma High-Cognition",
      leftFreq: 300,
      rightFreq: 340,
      description: "Creates a 40Hz Gamma beat. High-level cognitive processing, peak problem-solving. ⚡💻",
      category: "Energy",
    ),
    BinauralPreset(
      name: "Delta Deep Sleep",
      leftFreq: 100,
      rightFreq: 103.5,
      description: "Creates a 3.5Hz Delta beat. Accelerates deep sleep, body healing, and cell recovery. 💤🛌",
      category: "Sleep",
    ),
  ];
}
