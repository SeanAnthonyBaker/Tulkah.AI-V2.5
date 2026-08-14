import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_models.dart';
import '../providers/playback_provider.dart';

class IterativeAnswerViewer extends StatefulWidget {
  final List<AnswerEntryModel> answers;

  const IterativeAnswerViewer({Key? key, required this.answers}) : super(key: key);

  @override
  State<IterativeAnswerViewer> createState() => _IterativeAnswerViewerState();
}

class _IterativeAnswerViewerState extends State<IterativeAnswerViewer> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.answers.isNotEmpty ? widget.answers.length - 1 : 0;
  }

  @override
  void didUpdateWidget(covariant IterativeAnswerViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.answers.length != oldWidget.answers.length) {
      setState(() {
        _currentIndex = widget.answers.isNotEmpty ? widget.answers.length - 1 : 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.answers.isEmpty) {
      return const SizedBox.shrink();
    }

    final safeIndex = _currentIndex.clamp(0, widget.answers.length - 1);
    final currentAnswer = widget.answers[safeIndex];
    final hasMultiple = widget.answers.length > 1;
    final isLatest = safeIndex == widget.answers.length - 1;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Iteration Navigation Header Bar
          if (hasMultiple)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous Iteration Button
                  ElevatedButton.icon(
                    onPressed: safeIndex > 0
                        ? () {
                            setState(() {
                              _currentIndex--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 12, color: Colors.white),
                    label: const Text(
                      "PREV",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      disabledBackgroundColor: const Color(0xFF1E293B).withOpacity(0.4),
                      disabledForegroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(60, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  // Iteration Badge Indicator
                  Row(
                    children: [
                      const Icon(Icons.history_toggle_off, color: Color(0xFF818CF8), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        "Iteration ${safeIndex + 1} of ${widget.answers.length}",
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isLatest) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                          ),
                          child: const Text(
                            "LATEST",
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Next Iteration Button
                  ElevatedButton.icon(
                    onPressed: safeIndex < widget.answers.length - 1
                        ? () {
                            setState(() {
                              _currentIndex++;
                            });
                          }
                        : null,
                    icon: const Text(
                      "NEXT",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    label: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      disabledBackgroundColor: const Color(0xFF1E293B).withOpacity(0.4),
                      disabledForegroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(60, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Active Iteration Card
          AnswerCard(answer: currentAnswer),
        ],
      ),
    );
  }
}

class AnswerCard extends ConsumerWidget {
  final AnswerEntryModel answer;

  const AnswerCard({Key? key, required this.answer}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(playbackProvider);
    final isCurrentlyPlaying = playbackState.currentPlayingSeq == answer.seq &&
        (playbackState.status == PlaybackStatus.playingSingle ||
            playbackState.status == PlaybackStatus.playingAll);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCurrentlyPlaying
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF0F172A), const Color(0xFF020617)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentlyPlaying ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
          width: isCurrentlyPlaying ? 2 : 1.2,
        ),
        boxShadow: [
          if (isCurrentlyPlaying)
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.35),
              blurRadius: 14,
              spreadRadius: 2,
            )
          else
            const BoxShadow(
              color: Colors.black38,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCurrentlyPlaying
                            ? [const Color(0xFF6366F1), const Color(0xFF4F46E5)]
                            : [const Color(0xFF312E81), const Color(0xFF1E1B4B)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrentlyPlaying ? const Color(0xFF818CF8) : const Color(0xFF4338CA),
                      ),
                    ),
                    child: Text(
                      "Iteration #${answer.seq}",
                      style: const TextStyle(
                        color: Color(0xFFE0E7FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFF34D399), size: 12),
                        SizedBox(width: 4),
                        Text(
                          "Gemma 12B",
                          style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (isCurrentlyPlaying)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.volume_up, color: Color(0xFF38BDF8), size: 16),
                    ),
                  Text(
                    _formatTime(answer.recordedAt),
                    style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. PROMINENT PRIMARY: Local Spoken Language Baseline
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        answer.localLanguageBaseline != null
                            ? "PRIMARY: LOCAL SPOKEN LANGUAGE BASELINE [${answer.localLanguageBaseline!.languageCode.toUpperCase()}]"
                            : "PRIMARY: LOCAL SPOKEN LANGUAGE BASELINE",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  answer.localLanguageBaseline != null && answer.localLanguageBaseline!.transcript.isNotEmpty
                      ? answer.localLanguageBaseline!.transcript
                      : (answer.e4bTranscript.isNotEmpty ? answer.e4bTranscript : "No transcript recorded."),
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 8),

          // 2. SECONDARY SUBDUED: Corporate English Refinement (Gemma 12B)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.lock, color: Color(0xFF64748B), size: 13),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "SECONDARY: CORPORATE ENGLISH REFINEMENT",
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  answer.corporateEnglishBaseline != null && answer.corporateEnglishBaseline!.transcript.isNotEmpty
                      ? answer.corporateEnglishBaseline!.transcript
                      : (answer.gemma12bOutput.isNotEmpty ? answer.gemma12bOutput : "Awaiting English translation..."),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }
}

