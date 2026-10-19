import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'game_storage.dart';

class AudioManager {
  static bool _useSoloud = false;
  static final List<AudioSource> _soloudTileSources = [];
  static AudioSource? _soloudWordMatch;
  static AudioSource? _soloudExtraWord;
  static AudioSource? _soloudVictory;
  static AudioSource? _soloudInvalid;
  static AudioSource? _soloudBooster;
  static AudioSource? _soloudBgm;
  static SoundHandle? _soloudBgmHandle;

  // AudioPlayers Fallback Dedicated Player Instances
  static final List<ap.AudioPlayer> _tilePlayers = [];
  static ap.AudioPlayer? _matchPlayer;
  static ap.AudioPlayer? _extraPlayer;
  static ap.AudioPlayer? _victoryPlayer;
  static ap.AudioPlayer? _invalidPlayer;
  static ap.AudioPlayer? _boosterPlayer;
  static ap.AudioPlayer? _bgmPlayer;
  static bool _isBgmPlaying = false;
  static bool _isBgmPaused = false;
  static bool _isInitialized = false;

  /// Initialize and pre-warm audio engine (SoLoud C++ FFI primary, AudioPlayers with AudioFocus.none fallback)
  static Future<void> init() async {
    if (_isInitialized) return;

    // 1. Configure Global Audio Context to prevent OS AudioFocus thrashing & frame skipping
    try {
      final audioContext = ap.AudioContext(
        android: const ap.AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: ap.AndroidContentType.sonification,
          usageType: ap.AndroidUsageType.game,
          audioFocus: ap.AndroidAudioFocus.none, // CRITICAL: Stop Android OS audio focus arbitration!
        ),
        iOS: ap.AudioContextIOS(
          category: ap.AVAudioSessionCategory.ambient,
          options: const {
            ap.AVAudioSessionOptions.mixWithOthers,
          },
        ),
      );
      await ap.AudioPlayer.global.setAudioContext(audioContext);
    } catch (_) {}

    // 2. Attempt High-Performance SoLoud C++ FFI Engine (0ms Latency)
    try {
      await SoLoud.instance.init();
      if (SoLoud.instance.isInitialized) {
        _soloudTileSources.clear();
        for (int i = 1; i <= 6; i++) {
          final s = await SoLoud.instance.loadAsset('assets/audio/tile_select_$i.wav');
          _soloudTileSources.add(s);
        }
        _soloudWordMatch = await SoLoud.instance.loadAsset('assets/audio/word_match.wav');
        _soloudExtraWord = await SoLoud.instance.loadAsset('assets/audio/extra_word.wav');
        _soloudVictory = await SoLoud.instance.loadAsset('assets/audio/victory.wav');
        _soloudInvalid = await SoLoud.instance.loadAsset('assets/audio/invalid.wav');
        _soloudBooster = await SoLoud.instance.loadAsset('assets/audio/booster.wav');
        _soloudBgm = await SoLoud.instance.loadAsset('assets/audio/bgm.wav', mode: LoadMode.disk);
        _useSoloud = true;
      }
    } catch (_) {
      _useSoloud = false;
    }

    // 3. Pre-warm AudioPlayers fallback with dedicated AssetSources
    if (!_useSoloud) {
      try {
        _tilePlayers.clear();
        for (int i = 1; i <= 6; i++) {
          final p = ap.AudioPlayer(playerId: 'tile_player_$i');
          p.setPlayerMode(ap.PlayerMode.lowLatency).catchError((_) {});
          _tilePlayers.add(p);
        }

        _matchPlayer = ap.AudioPlayer(playerId: 'match_player');
        _matchPlayer!.setPlayerMode(ap.PlayerMode.lowLatency).catchError((_) {});

        _extraPlayer = ap.AudioPlayer(playerId: 'extra_player');
        _extraPlayer!.setPlayerMode(ap.PlayerMode.lowLatency).catchError((_) {});

        _victoryPlayer = ap.AudioPlayer(playerId: 'victory_player');
        _victoryPlayer!.setPlayerMode(ap.PlayerMode.lowLatency).catchError((_) {});

        _invalidPlayer = ap.AudioPlayer(playerId: 'invalid_player');
        _invalidPlayer!.setPlayerMode(ap.PlayerMode.lowLatency).catchError((_) {});

        _boosterPlayer = ap.AudioPlayer(playerId: 'booster_player');
        _boosterPlayer!.setPlayerMode(ap.PlayerMode.lowLatency).catchError((_) {});

        _bgmPlayer = ap.AudioPlayer(playerId: 'bgm_player');
        _bgmPlayer!.setReleaseMode(ap.ReleaseMode.loop).catchError((_) {});
        _bgmPlayer!.setVolume(0.25).catchError((_) {});
      } catch (_) {}
    }

    _isInitialized = true;
  }

  /// Play instant tactile tile click with progressive pitch note
  static void playTileSelect({int pitchIndex = 1}) {
    if (GameStorage.getSoundEnabled()) {
      final idx = (pitchIndex - 1).clamp(0, 5);
      if (_useSoloud && _soloudTileSources.length > idx) {
        try {
          SoLoud.instance.play(_soloudTileSources[idx], volume: 0.70);
        } catch (_) {}
      } else {
        try {
          if (_tilePlayers.length > idx) {
            _tilePlayers[idx].play(
              ap.AssetSource('audio/tile_select_${idx + 1}.wav'),
              volume: 0.70,
              mode: ap.PlayerMode.lowLatency,
            );
          }
        } catch (_) {}
      }
    }
    if (GameStorage.getHapticEnabled()) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }
  }

  static void playWordMatch({int combo = 1}) {
    if (GameStorage.getSoundEnabled()) {
      final double volume = (0.90 + min((combo - 1) * 0.03, 0.10)).clamp(0.0, 1.0);
      if (_useSoloud && _soloudWordMatch != null) {
        try {
          SoLoud.instance.play(_soloudWordMatch!, volume: volume);
        } catch (_) {}
      } else {
        try {
          _matchPlayer ??= ap.AudioPlayer(playerId: 'match_player');
          _matchPlayer?.play(
            ap.AssetSource('audio/word_match.wav'),
            volume: volume,
            mode: ap.PlayerMode.lowLatency,
          );
        } catch (_) {}
      }
    }
    if (GameStorage.getHapticEnabled()) {
      try {
        if (combo >= 3) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.mediumImpact();
        }
      } catch (_) {}
    }
  }

  static void playExtraWord() {
    if (GameStorage.getSoundEnabled()) {
      if (_useSoloud && _soloudExtraWord != null) {
        try {
          SoLoud.instance.play(_soloudExtraWord!, volume: 0.85);
        } catch (_) {}
      } else {
        try {
          _extraPlayer ??= ap.AudioPlayer(playerId: 'extra_player');
          _extraPlayer?.play(
            ap.AssetSource('audio/extra_word.wav'),
            volume: 0.85,
            mode: ap.PlayerMode.lowLatency,
          );
        } catch (_) {}
      }
    }
    if (GameStorage.getHapticEnabled()) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  static void playObstacleUnlock() {
    if (GameStorage.getSoundEnabled()) {
      if (_useSoloud && _soloudExtraWord != null) {
        try {
          SoLoud.instance.play(_soloudExtraWord!, volume: 0.90);
        } catch (_) {}
      } else {
        try {
          _extraPlayer ??= ap.AudioPlayer(playerId: 'extra_player');
          _extraPlayer?.play(
            ap.AssetSource('audio/extra_word.wav'),
            volume: 0.90,
            mode: ap.PlayerMode.lowLatency,
          );
        } catch (_) {}
      }
    }
    if (GameStorage.getHapticEnabled()) {
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }

  static void playVictory() {
    if (GameStorage.getSoundEnabled()) {
      if (_useSoloud && _soloudVictory != null) {
        try {
          SoLoud.instance.play(_soloudVictory!, volume: 1.0);
        } catch (_) {}
      } else {
        try {
          _victoryPlayer ??= ap.AudioPlayer(playerId: 'victory_player');
          _victoryPlayer?.play(
            ap.AssetSource('audio/victory.wav'),
            volume: 1.0,
            mode: ap.PlayerMode.lowLatency,
          );
        } catch (_) {}
      }
    }
    if (GameStorage.getHapticEnabled()) {
      try {
        HapticFeedback.vibrate();
      } catch (_) {}
    }
  }

  static void playInvalid() {
    if (GameStorage.getSoundEnabled()) {
      if (_useSoloud && _soloudInvalid != null) {
        try {
          SoLoud.instance.play(_soloudInvalid!, volume: 0.65);
        } catch (_) {}
      } else {
        try {
          _invalidPlayer ??= ap.AudioPlayer(playerId: 'invalid_player');
          _invalidPlayer?.play(
            ap.AssetSource('audio/invalid.wav'),
            volume: 0.65,
            mode: ap.PlayerMode.lowLatency,
          );
        } catch (_) {}
      }
    }
    if (GameStorage.getHapticEnabled()) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  static void playBooster() {
    if (GameStorage.getSoundEnabled()) {
      if (_useSoloud && _soloudBooster != null) {
        try {
          SoLoud.instance.play(_soloudBooster!, volume: 0.90);
        } catch (_) {}
      } else {
        try {
          _boosterPlayer ??= ap.AudioPlayer(playerId: 'booster_player');
          _boosterPlayer?.play(
            ap.AssetSource('audio/booster.wav'),
            volume: 0.90,
            mode: ap.PlayerMode.lowLatency,
          );
        } catch (_) {}
      }
    }
    if (GameStorage.getHapticEnabled()) {
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  static void startBgm() {
    if (!GameStorage.isMusicEnabled()) return;
    try {
      if (!_isBgmPlaying) {
        if (_useSoloud && _soloudBgm != null) {
          _soloudBgmHandle = SoLoud.instance.play(_soloudBgm!, looping: true, volume: 0.25);
        } else {
          _bgmPlayer?.play(ap.AssetSource('audio/bgm.wav'), volume: 0.25);
        }
        _isBgmPlaying = true;
        _isBgmPaused = false;
      }
    } catch (_) {}
  }

  static void pauseBgm() {
    try {
      if (_isBgmPlaying) {
        if (_useSoloud && _soloudBgmHandle != null) {
          SoLoud.instance.pauseSwitch(_soloudBgmHandle!);
        } else {
          _bgmPlayer?.pause();
        }
        _isBgmPaused = true;
      }
    } catch (_) {}
  }

  static void resumeBgm() {
    if (!GameStorage.isMusicEnabled()) return;
    try {
      if (_isBgmPaused) {
        if (_useSoloud && _soloudBgmHandle != null) {
          SoLoud.instance.pauseSwitch(_soloudBgmHandle!);
        } else {
          _bgmPlayer?.resume();
        }
        _isBgmPaused = false;
      } else if (!_isBgmPlaying) {
        startBgm();
      }
    } catch (_) {}
  }

  static void setMusicEnabled(bool enabled) {
    if (enabled) {
      if (_isBgmPaused) {
        resumeBgm();
      } else {
        startBgm();
      }
    } else {
      pauseBgm();
    }
  }

  static void stopBgm() {
    try {
      if (_useSoloud && _soloudBgmHandle != null) {
        SoLoud.instance.stop(_soloudBgmHandle!);
        _soloudBgmHandle = null;
      } else {
        _bgmPlayer?.stop();
      }
      _isBgmPlaying = false;
      _isBgmPaused = false;
    } catch (_) {}
  }

  static void syncSoundSettings() {
    if (GameStorage.getSoundEnabled()) {
      startBgm();
    } else {
      stopBgm();
    }
  }
}
