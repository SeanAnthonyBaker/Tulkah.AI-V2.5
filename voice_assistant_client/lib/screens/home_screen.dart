import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_models.dart';
import '../providers/session_provider.dart';
import '../providers/playback_provider.dart';
import '../widgets/answer_card.dart';
import '../widgets/hold_to_record_button.dart';

const Map<String, String> interviewLanguages = {
  'auto': '🌐 Auto-Detect',
  'ru': '🇷🇺 Russian (Русский)',
  'en': '🇬🇧 English',
  'es': '🇪🇸 Spanish (Español)',
  'fr': '🇫🇷 French (Français)',
  'de': '🇩🇪 German (Deutsch)',
  'zh': '🇨🇳 Mandarin (中文)',
  'ar': '🇸🇦 Arabic (العربية)',
  'pt': '🇵🇹 Portuguese (Português)',
  'hi': '🇮🇳 Hindi (हिन्दी)',
  'sw': '🇰🇪 Swahili (Kiswahili)',
};

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedTabStatus = "current";

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final playbackState = ref.watch(playbackProvider);
    final sessionNotifier = ref.read(sessionProvider.notifier);
    final playbackNotifier = ref.read(playbackProvider.notifier);

    final allThreads = sessionState.session?.questionThreads ?? [];
    final activeThread = sessionState.activeThread;

    final currentTabThreads = allThreads.where((t) => t.status == _selectedTabStatus).toList();
    final answers = activeThread?.answers ?? [];

    final isPlayingActiveThread = (playbackState.status == PlaybackStatus.playingAll ||
            playbackState.status == PlaybackStatus.playingSingle) &&
        playbackState.currentPlayingThreadId == activeThread?.threadId;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.analytics, color: Color(0xFF6366F1)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Process Improvement Q&A",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showServerSettingsDialog(context, ref),
            tooltip: "Server IP Settings",
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt, color: Color(0xFFF43F5E)),
            onPressed: () async {
              playbackNotifier.stopPlayback();
              await sessionNotifier.resetSessionToBeginning();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("🔄 Q&A Reset: 0 answers, Question 1 is active!"),
                    backgroundColor: Color(0xFFF43F5E),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            tooltip: "Reset Q&A back to beginning",
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Question Pipeline Tabs
            Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                children: [
                  _buildTabHeaderButton(
                    label: "ANSWERED (${allThreads.where((t) => t.status == 'previous').length})",
                    status: "previous",
                  ),
                  const SizedBox(width: 8),
                  _buildTabHeaderButton(
                    label: activeThread != null
                        ? "✅ QUESTION #${activeThread.sortOrder}"
                        : "✅ NEXT QUESTION",
                    status: "current",
                  ),
                  const SizedBox(width: 8),
                  _buildTabHeaderButton(
                    label: activeThread != null && allThreads.any((t) => t.status == 'upcoming')
                        ? "UPCOMING (#${activeThread.sortOrder + 1})"
                        : "UPCOMING (0)",
                    status: "upcoming",
                  ),
                ],
              ),
            ),

            // 1.5 Interviewee Preferred Spoken Language Bar
            Container(
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.language, color: Color(0xFF38BDF8), size: 16),
                      SizedBox(width: 6),
                      Text(
                        "INTERVIEWEE LANGUAGE",
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8), width: 1.0),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: sessionState.selectedLanguage,
                        dropdownColor: const Color(0xFF0F172A),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF38BDF8)),
                        isDense: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onChanged: (String? newLang) {
                          if (newLang != null) {
                            sessionNotifier.setLanguage(newLang);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("🌐 Interviewee Preferred Language set to: ${interviewLanguages[newLang]}"),
                                backgroundColor: const Color(0xFF0284C7),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        items: interviewLanguages.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Active Question Banner (When on 'current' tab)
            if (_selectedTabStatus == "current")
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(bottom: BorderSide(color: Color(0xFF334155))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "ACTIVE PROCESS QUESTION #${activeThread?.sortOrder ?? 1} OF ${allThreads.isNotEmpty ? allThreads.length : 15}",
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 1.1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (answers.isNotEmpty)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Color(0xFF34D399), width: 1.2),
                              ),
                              elevation: 3,
                            ),
                            onPressed: () {
                              playbackNotifier.stopPlayback();
                              sessionNotifier.acceptCurrentAnswer();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("✓ Process Answer Accepted! Moved to Answered list."),
                                  backgroundColor: Color(0xFF10B981),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                            label: const Text(
                              "ACCEPT ANSWER",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activeThread?.questionText ?? "No active question selected.",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

            // 3. EXECUTIVE ACTION TOOLBAR (Horizontal Scrollable Pill Bar - Zero Overflow)
            if (_selectedTabStatus == "current")
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                  border: Border.symmetric(
                    horizontal: BorderSide(color: Color(0xFF334155), width: 1.0),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Button 1: Read / Stop Button
                      ElevatedButton.icon(
                        onPressed: answers.isNotEmpty && activeThread != null
                            ? () {
                                if (isPlayingActiveThread) {
                                  playbackNotifier.stopPlayback();
                                } else {
                                  playbackNotifier.playLatestLocalBaseline(activeThread.threadId, answers);
                                }
                              }
                            : null,
                        icon: Icon(
                          isPlayingActiveThread ? Icons.stop : Icons.volume_up,
                          color: Colors.white,
                          size: 15,
                        ),
                        label: Text(
                          isPlayingActiveThread ? "Stop" : "Read",
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white, letterSpacing: 0.3),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPlayingActiveThread ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
                          disabledBackgroundColor: const Color(0xFF1E293B),
                          disabledForegroundColor: const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isPlayingActiveThread ? const Color(0xFFFCA5A5) : const Color(0xFF818CF8),
                              width: 1.2,
                            ),
                          ),
                          elevation: 3,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Button 2: Consolidate Button (Reworks random appends into a unified baseline)
                      ElevatedButton.icon(
                        onPressed: answers.isNotEmpty
                            ? () {
                                playbackNotifier.stopPlayback();
                                sessionNotifier.consolidateCurrentAnswers();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("✨ Gemma 12B consolidated random appends into a unified baseline!"),
                                    backgroundColor: Color(0xFF7C3AED),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
                        label: const Text(
                          "Consolidate",
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white, letterSpacing: 0.3),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          disabledBackgroundColor: const Color(0xFF1E293B),
                          disabledForegroundColor: const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFC084FC), width: 1.2),
                          ),
                          elevation: 3,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Button 3: Clear Button
                      ElevatedButton.icon(
                        onPressed: answers.isNotEmpty
                            ? () {
                                playbackNotifier.stopPlayback();
                                sessionNotifier.clearCurrentAnswer();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Draft answer cleared"),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.delete_outline, color: Colors.white, size: 15),
                        label: const Text(
                          "Clear",
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white, letterSpacing: 0.3),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB91C1C),
                          disabledBackgroundColor: const Color(0xFF1E293B),
                          disabledForegroundColor: const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFF87171), width: 1.2),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Error banner if any
            if (sessionState.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF7F1D1D),
                child: Text(
                  sessionState.errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),

            // 4. Tab Body Content
            Expanded(
              child: sessionState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                    )
                  : _selectedTabStatus == "current"
                      ? (answers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.analytics_outlined, size: 48, color: Color(0xFF334155)),
                                  SizedBox(height: 12),
                                  Text(
                                    "No process assessment entries recorded yet.",
                                    style: TextStyle(color: Color(0xFF64748B)),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Hold the speak button below or type to answer.",
                                    style: TextStyle(color: Color(0xFF475569), fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : IterativeAnswerViewer(answers: answers))
                      : _buildThreadsTabList(currentTabThreads, sessionNotifier, ref),
            ),

            // 5. Bottom Hold-to-Record Button (Shown in 'current' tab)
            if (_selectedTabStatus == "current")
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: HoldToRecordButton(
                  onRecordStart: () {
                    playbackNotifier.stopPlayback();
                  },
                  onRecordComplete: (audioPath) {
                    sessionNotifier.processRecordedAudio(audioPath);
                  },
                  onTextSubmit: (text) {
                    sessionNotifier.processTextInput(text);
                  },
                  onRecordCancel: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Recording cancelled — no data sent"),
                        duration: Duration(seconds: 1),
                        backgroundColor: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabHeaderButton({required String label, required String status}) {
    final isSelected = _selectedTabStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabStatus = status;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF475569),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThreadsTabList(List<QuestionThreadModel> threads, SessionNotifier notifier, WidgetRef ref) {
    if (threads.isEmpty) {
      return Center(
        child: Text(
          _selectedTabStatus == "previous"
              ? "No completed process questions yet.\nAccept answers in the NEXT BEST QUESTION tab."
              : "No upcoming process improvement questions queued.",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    final playbackState = ref.watch(playbackProvider);
    final playbackNotifier = ref.read(playbackProvider.notifier);

    return ListView.builder(
      itemCount: threads.length,
      itemBuilder: (context, index) {
        final thread = threads[index];
        final latestAnswerObj = thread.answers.isNotEmpty ? thread.answers.last : null;
        final latestAnswer = latestAnswerObj?.gemma12bOutput;

        final isThreadPlaying = playbackState.currentPlayingThreadId == thread.threadId &&
            (playbackState.status == PlaybackStatus.playingSingle || playbackState.status == PlaybackStatus.playingAll);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _selectedTabStatus == "previous"
                            ? const Color(0xFF065F46)
                            : const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedTabStatus == "previous"
                            ? "ANSWERED #${thread.sortOrder}"
                            : "UPCOMING #${thread.sortOrder}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (_selectedTabStatus == "previous" && latestAnswerObj != null)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isThreadPlaying ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isThreadPlaying ? const Color(0xFFFCA5A5) : const Color(0xFF818CF8),
                              width: 1.2,
                            ),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          if (isThreadPlaying) {
                            playbackNotifier.stopPlayback();
                          } else {
                            playbackNotifier.playSingleAnswer(thread.threadId, latestAnswerObj);
                          }
                        },
                        icon: Icon(
                          isThreadPlaying ? Icons.stop : Icons.volume_up,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: Text(
                          isThreadPlaying ? "Stop" : "Read",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (_selectedTabStatus == "upcoming")
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isThreadPlaying ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isThreadPlaying ? const Color(0xFFFCA5A5) : const Color(0xFF818CF8),
                              width: 1.2,
                            ),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          if (isThreadPlaying) {
                            playbackNotifier.stopPlayback();
                          } else {
                            playbackNotifier.playText(thread.threadId, thread.questionText);
                          }
                        },
                        icon: Icon(
                          isThreadPlaying ? Icons.stop : Icons.volume_up,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: Text(
                          isThreadPlaying ? "Stop" : "Read Question",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  thread.questionText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (latestAnswer != null) ...[
                  const SizedBox(height: 10),
                  const Divider(color: Color(0xFF334155)),
                  const SizedBox(height: 4),
                  const Text(
                    "Accepted Process Answer:",
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    latestAnswer,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }



  void _showServerSettingsDialog(BuildContext context, WidgetRef ref) {
    final currentUrl = ref.read(apiServiceProvider).baseUrl;
    final controller = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            children: const [
              Icon(Icons.wifi_tethering, color: Color(0xFF6366F1)),
              SizedBox(width: 10),
              Text("Server IP Settings", style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter Antigravity backend server URL or IP address:",
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "http://192.168.1.77:8080",
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final newUrl = controller.text.trim();
                if (newUrl.isNotEmpty) {
                  ref.read(sessionProvider.notifier).updateServerUrl(newUrl);
                }
                Navigator.pop(context);
              },
              child: const Text("Save & Connect", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
