import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'audio_waveform_widget.dart';

enum RecordButtonState { idle, recording, cancelled }

class HoldToRecordButton extends StatefulWidget {
  final Function() onRecordStart;
  final Function(String audioPath) onRecordComplete;
  final Function() onRecordCancel;
  final Function(String text)? onTextSubmit;

  const HoldToRecordButton({
    Key? key,
    required this.onRecordStart,
    required this.onRecordComplete,
    required this.onRecordCancel,
    this.onTextSubmit,
  }) : super(key: key);

  @override
  State<HoldToRecordButton> createState() => _HoldToRecordButtonState();
}

class _HoldToRecordButtonState extends State<HoldToRecordButton> with SingleTickerProviderStateMixin {
  RecordButtonState _buttonState = RecordButtonState.idle;
  late AnimationController _pulseController;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _timer;
  int _recordDurationSeconds = 0;
  double _liveAudioLevel = 0.3;
  Offset _startTapPosition = Offset.zero;
  static const double _cancelThresholdPx = 80.0;
  String? _currentRecordingPath;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording(LongPressStartDetails details) async {
    setState(() {
      _buttonState = RecordButtonState.recording;
      _startTapPosition = details.globalPosition;
      _recordDurationSeconds = 0;
      _liveAudioLevel = 0.3;
    });

    widget.onRecordStart();

    // Start 16kHz WAV audio capture & amplitude streaming
    try {
      if (await _audioRecorder.hasPermission()) {
        if (kIsWeb) {
          _currentRecordingPath = null;
          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: 16000,
              numChannels: 1,
            ),
            path: '',
          );
        } else {
          final tempDir = await getTemporaryDirectory();
          _currentRecordingPath = '${tempDir.path}/recorded_audio_16k_mono.wav';

          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: 16000,
              numChannels: 1,
            ),
            path: _currentRecordingPath!,
          );
        }

        _amplitudeSubscription?.cancel();
        _amplitudeSubscription = _audioRecorder
            .onAmplitudeChanged(const Duration(milliseconds: 60))
            .listen((amp) {
          if (mounted) {
            double db = amp.current;
            double norm = ((db + 60.0) / 60.0).clamp(0.1, 1.0);
            setState(() {
              _liveAudioLevel = norm;
            });
          }
        });
      }
    } catch (e) {
      // Fallback
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordDurationSeconds++;
        });
      }
    });
  }

  void _onDragUpdate(LongPressMoveUpdateDetails details) {
    final distance = (details.globalPosition - _startTapPosition).distance;
    if (distance > _cancelThresholdPx && _buttonState == RecordButtonState.recording) {
      setState(() {
        _buttonState = RecordButtonState.cancelled;
      });
    } else if (distance <= _cancelThresholdPx && _buttonState == RecordButtonState.cancelled) {
      setState(() {
        _buttonState = RecordButtonState.recording;
      });
    }
  }

  Future<void> _endRecording(LongPressEndDetails details) async {
    _timer?.cancel();
    _amplitudeSubscription?.cancel();

    String? finalPath;
    try {
      finalPath = await _audioRecorder.stop();
    } catch (e) {
      // Fallback
    }

    if (_buttonState == RecordButtonState.cancelled) {
      widget.onRecordCancel();
    } else if (_buttonState == RecordButtonState.recording) {
      final actualPath = finalPath ?? _currentRecordingPath ?? '/tmp/recorded_audio_16k_mono.wav';
      widget.onRecordComplete(actualPath);
    }

    setState(() {
      _buttonState = RecordButtonState.idle;
      _recordDurationSeconds = 0;
      _liveAudioLevel = 0.3;
    });
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }



  @override
  Widget build(BuildContext me) {
    final isRecording = _buttonState == RecordButtonState.recording;
    final isCancelled = _buttonState == RecordButtonState.cancelled;

    // 3D Colors & Gradients
    List<Color> gradientColors = [const Color(0xFF818CF8), const Color(0xFF4F46E5), const Color(0xFF3730A3)];
    Color bottomShadowColor = const Color(0xFF1E1B4B);
    Color borderColor = Colors.white.withOpacity(0.35);

    if (isRecording) {
      gradientColors = [const Color(0xFFF87171), const Color(0xFFEF4444), const Color(0xFFB91C1C)];
      bottomShadowColor = const Color(0xFF450A0A);
    } else if (isCancelled) {
      gradientColors = [const Color(0xFF9CA3AF), const Color(0xFF6B7280), const Color(0xFF374151)];
      bottomShadowColor = const Color(0xFF111827);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isRecording || isCancelled) ...[
          Text(
            isCancelled ? "SLIDE BACK OR RELEASE TO CANCEL" : "RECORDING ${_formatDuration(_recordDurationSeconds)}",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isCancelled ? Colors.orangeAccent : Colors.redAccent,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          // Active wave image animation driven by live microphone audio amplitude
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            height: 26,
            child: AudioWaveformWidget(
              isPlaying: isRecording,
              audioLevel: _liveAudioLevel,
              height: 22,
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isCancelled ? "❌ Recording will be discarded" : "◄ Slide off button to cancel",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Center 3D Speak Button
            GestureDetector(
              onLongPressStart: _startRecording,
              onLongPressMoveUpdate: _onDragUpdate,
              onLongPressEnd: _endRecording,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = isRecording ? 1.0 + (_pulseController.value * 0.08) : 1.0;
                  final translateOffset = isRecording ? const Offset(0, 4) : const Offset(0, 0);

                  return Transform.translate(
                    offset: translateOffset,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: gradientColors,
                          ),
                          border: Border.all(
                            color: borderColor,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: bottomShadowColor,
                              offset: Offset(0, isRecording ? 2 : 6),
                              blurRadius: isRecording ? 4 : 8,
                            ),
                            BoxShadow(
                              color: gradientColors[1].withOpacity(isRecording ? 0.7 : 0.4),
                              offset: const Offset(0, 2),
                              blurRadius: isRecording ? 16 : 8,
                              spreadRadius: isRecording ? 2 : 0,
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              offset: const Offset(0, -1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isRecording ? Icons.mic : (isCancelled ? Icons.delete_forever : Icons.mic_none),
                              color: Colors.white,
                              shadows: const [
                                Shadow(
                                  color: Colors.black45,
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isRecording
                                  ? "RELEASE TO PROCESS"
                                  : (isCancelled ? "DISCARD" : "🎤 HOLD TO SPEAK"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.8,
                                shadows: [
                                  Shadow(
                                    color: Colors.black45,
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
