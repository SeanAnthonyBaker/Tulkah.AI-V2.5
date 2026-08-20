import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final textContent = answer.e4bTranscript.isNotEmpty
        ? answer.e4bTranscript
        : (answer.localLanguageBaseline != null && answer.localLanguageBaseline!.transcript.isNotEmpty
            ? answer.localLanguageBaseline!.transcript
            : "Hold the speak button below to start answering...");

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180, maxHeight: 380),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 30, left: 4, bottom: 4),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SelectableText(
                textContent,
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.copy, color: Color(0xFF38BDF8), size: 16),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              tooltip: "Copy text to Clipboard for MS Teams",
              onPressed: () {
                if (textContent.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: textContent));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("📋 Spoken answer copied to clipboard!"),
                      backgroundColor: Color(0xFF0284C7),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
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

