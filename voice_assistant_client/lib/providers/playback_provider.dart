import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/session_models.dart';

enum PlaybackStatus { stopped, playingAll, playingSingle, paused }

class PlaybackState {
  final PlaybackStatus status;
  final String? currentPlayingThreadId;
  final int? currentPlayingSeq;
  final double progress;

  PlaybackState({
    this.status = PlaybackStatus.stopped,
    this.currentPlayingThreadId,
    this.currentPlayingSeq,
    this.progress = 0.0,
  });

  PlaybackState copyWith({
    PlaybackStatus? status,
    String? currentPlayingThreadId,
    int? currentPlayingSeq,
    double? progress,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      currentPlayingThreadId: currentPlayingThreadId ?? this.currentPlayingThreadId,
      currentPlayingSeq: currentPlayingSeq ?? this.currentPlayingSeq,
      progress: progress ?? this.progress,
    );
  }
}

class PlaybackNotifier extends StateNotifier<PlaybackState> {
  final FlutterTts _flutterTts = FlutterTts();
  List<AnswerEntryModel> _playlist = [];
  int _playlistIndex = 0;

  PlaybackNotifier() : super(PlaybackState()) {
    _initTts();
  }

  void _initTts() async {
    try {
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
    } catch (_) {}

    // Try setting a preferred UK voice if available on Android
    try {
      final voices = await _flutterTts.getVoices;
      if (voices != null) {
        for (var voice in voices) {
          if (voice is Map) {
            final locale = voice["locale"]?.toString() ?? "";
            final name = voice["name"]?.toString() ?? "";
            if (locale.contains("en-GB") || locale.contains("en_GB") || name.contains("en-gb")) {
              await _flutterTts.setVoice({"name": name, "locale": locale});
              break;
            }
          }
        }
      }
    } catch (_) {
      // Fallback to default en-GB
    }

    _flutterTts.setStartHandler(() {
      if (state.status != PlaybackStatus.playingAll) {
        state = state.copyWith(status: PlaybackStatus.playingSingle);
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (state.status == PlaybackStatus.playingAll) {
        _playNextInPlaylist();
      } else {
        stopPlayback();
      }
    });

    _flutterTts.setCancelHandler(() {
      state = PlaybackState(status: PlaybackStatus.stopped);
    });

    _flutterTts.setErrorHandler((msg) {
      state = PlaybackState(status: PlaybackStatus.stopped);
    });
  }

  Future<void> playText(String threadId, String text) async {
    await stopPlayback();
    state = PlaybackState(
      status: PlaybackStatus.playingSingle,
      currentPlayingThreadId: threadId,
      currentPlayingSeq: 0,
    );
    await _flutterTts.speak(text);
  }

  Future<void> playAllAnswers(String threadId, List<AnswerEntryModel> answers) async {
    if (answers.isEmpty) return;
    await stopPlayback();

    _playlist = List.from(answers);
    _playlist.sort((a, b) => a.seq.compareTo(b.seq));
    _playlistIndex = 0;

    state = PlaybackState(
      status: PlaybackStatus.playingAll,
      currentPlayingThreadId: threadId,
      currentPlayingSeq: _playlist[_playlistIndex].seq,
    );
    await _speakEntry(_playlist[_playlistIndex]);
  }

  Future<void> playLatestLocalBaseline(String threadId, List<AnswerEntryModel> answers) async {
    if (answers.isEmpty) return;
    await stopPlayback();

    final latestAnswer = answers.reduce((a, b) => a.seq > b.seq ? a : b);
    final textToSpeak = latestAnswer.localLanguageBaseline?.transcript ?? latestAnswer.e4bTranscript;

    if (textToSpeak.trim().isEmpty) return;

    state = PlaybackState(
      status: PlaybackStatus.playingSingle,
      currentPlayingThreadId: threadId,
      currentPlayingSeq: latestAnswer.seq,
    );

    try {
      await _flutterTts.setEngine("com.google.android.tts");
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.speak(textToSpeak);
    } catch (e) {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.speak(textToSpeak);
    }
  }

  Future<void> playSingleAnswer(String threadId, AnswerEntryModel answer) async {
    await stopPlayback();
    state = PlaybackState(
      status: PlaybackStatus.playingSingle,
      currentPlayingThreadId: threadId,
      currentPlayingSeq: answer.seq,
    );
    await _speakEntry(answer);
  }

  Future<void> restartPlayback(String threadId, List<AnswerEntryModel> answers) async {
    await stopPlayback();
    await playLatestLocalBaseline(threadId, answers);
  }

  Future<void> _speakEntry(AnswerEntryModel answer) async {
    state = state.copyWith(currentPlayingSeq: answer.seq);
    String textToSpeak = answer.localLanguageBaseline?.transcript ?? answer.e4bTranscript;
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setVolume(1.0);
      await _flutterTts.speak(textToSpeak);
    } catch (_) {}
  }

  Future<void> _playNextInPlaylist() async {
    _playlistIndex++;
    if (_playlistIndex < _playlist.length) {
      await _speakEntry(_playlist[_playlistIndex]);
    } else {
      await stopPlayback();
    }
  }

  Future<void> pausePlayback() async {
    state = state.copyWith(status: PlaybackStatus.paused);
    await _flutterTts.pause();
  }

  Future<void> resumePlayback(String threadId, List<AnswerEntryModel> answers) async {
    state = state.copyWith(status: PlaybackStatus.playingAll);
    if (_playlist.isNotEmpty && _playlistIndex < _playlist.length) {
      await _speakEntry(_playlist[_playlistIndex]);
    } else {
      await playAllAnswers(threadId, answers);
    }
  }

  Future<void> stopPlayback() async {
    state = PlaybackState(status: PlaybackStatus.stopped);
    await _flutterTts.stop();
    _playlist.clear();
    _playlistIndex = 0;
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}

final playbackProvider = StateNotifierProvider<PlaybackNotifier, PlaybackState>((ref) {
  return PlaybackNotifier();
});
