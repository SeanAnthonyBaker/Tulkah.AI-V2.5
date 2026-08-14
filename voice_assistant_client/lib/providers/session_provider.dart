import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/session_models.dart';
import '../services/api_service.dart';
import '../services/e4b_client_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final e4bServiceProvider = Provider<E4BClientService>((ref) => E4BClientService());

class SessionState {
  final SessionModel? session;
  final String activeThreadId;
  final String selectedLanguage;
  final bool isLoading;
  final String? errorMessage;

  SessionState({
    this.session,
    this.activeThreadId = 'thr_101',
    this.selectedLanguage = 'en',
    this.isLoading = false,
    this.errorMessage,
  });

  SessionState copyWith({
    SessionModel? session,
    String? activeThreadId,
    String? selectedLanguage,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SessionState(
      session: session ?? this.session,
      activeThreadId: activeThreadId ?? this.activeThreadId,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  QuestionThreadModel? get activeThread {
    if (session == null) return null;
    return session!.questionThreads.firstWhere(
      (t) => t.threadId == activeThreadId,
      orElse: () => session!.questionThreads.isNotEmpty
          ? session!.questionThreads.first
          : QuestionThreadModel(
              threadId: 'thr_105',
              questionText: 'Active Question',
              status: 'current',
              sortOrder: 5,
              answers: [],
            ),
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  final ApiService _apiService;
  final E4BClientService _e4bService;

  SessionNotifier(this._apiService, this._e4bService) : super(SessionState()) {
    loadDefaultSession();
  }

  Future<void> updateServerUrl(String newUrl) async {
    _apiService.updateBaseUrl(newUrl);
    await loadDefaultSession();
  }

  Future<void> loadDefaultSession() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await _apiService.getSession('sess_default');
      String initialActiveId = 'thr_101';
      for (var t in session.questionThreads) {
        if (t.status == 'current') {
          initialActiveId = t.threadId;
          break;
        }
      }
      state = state.copyWith(
        session: session,
        activeThreadId: initialActiveId,
        isLoading: false,
      );
    } catch (e) {
      final nowStr = DateTime.now().toIso8601String();
      final fallbackSession = SessionModel(
        sessionId: 'sess_default',
        questionThreads: [
          // 4 Answered Process Improvement Questions
          QuestionThreadModel(
            threadId: 'thr_101',
            questionText: 'What standard operating metrics and value-stream mapping techniques do you use to identify processing bottlenecks in high-volume Accounts Payable workflows?',
            status: 'previous',
            sortOrder: 1,
            answers: [
              AnswerEntryModel(
                seq: 1,
                e4bTranscript: "We map cycle times from receipt to ERP posting and isolate buyer approval bottlenecks.",
                gemma12bOutput: "We deploy Value Stream Mapping (VSM) to track invoice cycle time from initial OCR receipt to ERP posting. By analyzing queue dwell times between buyer approval steps and ERP exception queues, we pin-point hand-off delays and eliminate non-value-added manual touchpoints.",
                recordedAt: nowStr,
              )
            ],
          ),
          QuestionThreadModel(
            threadId: 'thr_102',
            questionText: 'How do you streamline the 3-Way Matching exception process to increase touchless invoice processing rates above 95%?',
            status: 'previous',
            sortOrder: 2,
            answers: [
              AnswerEntryModel(
                seq: 1,
                e4bTranscript: "We set automated line tolerances in SAP and auto-route exception tickets to purchasing.",
                gemma12bOutput: "We audit line-item tolerance thresholds, implement automated PO line-matching rules in SAP/NetSuite, and establish automated workflow routing to buyers for out-of-tolerance variances. This eliminated manual 3-way verification for 92% of recurring supplier invoices.",
                recordedAt: nowStr,
              )
            ],
          ),
          QuestionThreadModel(
            threadId: 'thr_103',
            questionText: 'What root-cause analysis methods (such as 5 Whys or Fishbone diagrams) do you execute when vendor payment discrepancies or duplicate payments occur?',
            status: 'previous',
            sortOrder: 3,
            answers: [
              AnswerEntryModel(
                seq: 1,
                e4bTranscript: "We run 5 Whys analysis on duplicate payment slips to fix root-cause ingestion rules.",
                gemma12bOutput: "We conduct 5-Whys root cause analysis on every payment anomaly. When a duplicate invoice slip occurred due to multi-channel receipt (email + EDI), we re-engineered the front-end ingestion engine to deduplicate files at the point of OCR entry before creating ERP staging records.",
                recordedAt: nowStr,
              )
            ],
          ),
          QuestionThreadModel(
            threadId: 'thr_104',
            questionText: 'How do you evaluate and optimize vendor payment terms (e.g., transitioning from Net 30 to dynamic 2/10 Net 30 discounting) to improve working capital yield?',
            status: 'previous',
            sortOrder: 4,
            answers: [
              AnswerEntryModel(
                seq: 1,
                e4bTranscript: "We analyze vendor payment terms using dynamic discounting algorithms.",
                gemma12bOutput: "We perform portfolio term optimization by benchmarking vendor APR yield against our internal hurdle rate. Implementing automated dynamic discounting workflows captured an additional \$420k in early payment discounts while maintaining vendor goodwill and cash flow stability.",
                recordedAt: nowStr,
              )
            ],
          ),

          // 1 Active Current Question
          QuestionThreadModel(
            threadId: 'thr_105',
            questionText: 'How do you design and implement continuous improvement (Kaizen) cycles to optimize Accounts Payable SLA performance and reduce cost per invoice processed?',
            status: 'current',
            sortOrder: 5,
            answers: [
              AnswerEntryModel(
                seq: 1,
                e4bTranscript: "We run bi-weekly Kaizen reviews tracking touchless rate and invoice processing cost.",
                gemma12bOutput: "We run bi-weekly Kaizen reviews tracking touchless processing rate, first-pass accuracy, and cost-per-invoice metrics. By automating recurring utility and SaaS invoice posting rules, we reduced processing cost from \$12.50 to \$2.10 per invoice while improving SLA turnaround from 8 days to under 24 hours.",
                recordedAt: nowStr,
              )
            ],
          ),

          // 10 Upcoming Process Improvement Questions
          QuestionThreadModel(
            threadId: 'thr_106',
            questionText: 'How do you optimize the Goods Received/Invoice Received (GR/IR) clearing process to minimize unvouched liabilities and month-end closing lag?',
            status: 'upcoming',
            sortOrder: 6,
            answers: [],
          ),
          QuestionThreadModel(
            threadId: 'thr_107',
            questionText: 'What process controls and automated validation rules do you implement to eliminate vendor master file duplication and bank routing fraud risk?',
            status: 'upcoming',
            sortOrder: 7,
            answers: [],
          ),
          QuestionThreadModel(
            threadId: 'thr_108',
            questionText: 'How do you restructure the employee expense management process (Concur/Expensify) to enforce policy compliance without delaying employee reimbursements?',
            status: 'upcoming',
            sortOrder: 8,
            answers: [],
          ),
          QuestionThreadModel(
            threadId: 'thr_109',
            questionText: 'How do you measure and reduce cycle time variation between paper-based invoice capture versus automated digital intake?',
            status: 'upcoming',
            sortOrder: 9,
            answers: [],
          ),
          QuestionThreadModel(
            threadId: 'thr_110',
            questionText: 'What process metrics and executive dashboards do you construct to provide real-time visibility into AP operational efficiency and cash outflow timing?',
            status: 'upcoming',
            sortOrder: 10,
            answers: [],
          ),
          QuestionThreadModel(
            threadId: 'thr_111',
            questionText: 'How do you streamline multi-currency cross-border payment processing to eliminate foreign exchange (FX) fee leakage and transfer delays?',
            status: 'upcoming',
            sortOrder: 11,
            answers: [],
          ),
          QuestionThreadModel(
            threadId: 'thr_112',
            questionText: 'What methodology do you follow to map, optimize, and standardize AP workflows during a post-merger ERP system consolidation?',
            status: 'upcoming',
            sortOrder: 12,
            answers: [],
          ),
          QuestionThreadModel(
            threadId: 'thr_113',
            questionText: 'How do you optimize 1099/1042-S tax compliance workflows to automate year-end vendor reporting with zero manual reconciliation?',
            status: 'upcoming',
            sortOrder: 13,
            answers: [],
          ),
          QuestionThreadModel(
            threadId: 'thr_114',
            questionText: 'How do you eliminate manual out-of-cycle emergency check requests by establishing standard SLA payment run schedules?',
            status: 'upcoming',
            sortOrder: 14,
            answers: [],
          ),
          QuestionThreadModel(
            threadId: 'thr_115',
            questionText: 'What process governance framework ensures continuous audit readiness for SOX 404 compliance without creating administrative drag?',
            status: 'upcoming',
            sortOrder: 15,
            answers: [],
          ),
        ],
      );
      state = state.copyWith(
        session: fallbackSession,
        activeThreadId: 'thr_105',
        isLoading: false,
        errorMessage: 'Loaded cached local session (Offline mode)',
      );
    }
  }

  Future<void> resetSessionToBeginning() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await _apiService.resetSession('sess_default');
      state = state.copyWith(
        session: session,
        activeThreadId: 'thr_101',
        isLoading: false,
      );
    } catch (e) {
      // Offline fallback: reset local state to thr_101 as active
      if (state.session != null) {
        final resetThreads = state.session!.questionThreads.map((t) {
          if (t.threadId == 'thr_101') {
            return t.copyWith(status: 'current', answers: []);
          }
          return t.copyWith(status: 'upcoming', answers: []);
        }).toList();
        state = state.copyWith(
          session: SessionModel(
            sessionId: state.session!.sessionId,
            questionThreads: resetThreads,
          ),
          activeThreadId: 'thr_101',
          isLoading: false,
        );
      }
    }
  }

  void setLanguage(String langCode) {
    state = state.copyWith(selectedLanguage: langCode);
  }

  void setActiveThread(String threadId) {
    state = state.copyWith(activeThreadId: threadId);
  }

  Future<void> clearCurrentAnswer() async {
    final currentThreadId = state.activeThreadId;
    final currentSession = state.session;
    if (currentSession == null) return;

    // Optimistic local state clearing so UI updates instantly!
    final optimisticThreads = currentSession.questionThreads.map((t) {
      if (t.threadId == currentThreadId) {
        return t.copyWith(answers: []);
      }
      return t;
    }).toList();

    state = state.copyWith(
      session: SessionModel(
        sessionId: currentSession.sessionId,
        questionThreads: optimisticThreads,
      ),
      isLoading: false,
      errorMessage: null,
    );

    // Call backend API to clear answer in database asynchronously
    try {
      final updatedSession = await _apiService.clearThread(currentSession.sessionId, currentThreadId);
      state = state.copyWith(session: updatedSession);
    } catch (e) {
      // Keep optimistic cleared state
    }
  }

  Future<void> acceptCurrentAnswer() async {
    final currentSession = state.session;
    final currentThreadId = state.activeThreadId;
    if (currentSession == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final updatedSession = await _apiService.acceptThread(currentSession.sessionId, currentThreadId);
      String nextActiveId = '';
      for (var t in updatedSession.questionThreads) {
        if (t.status == 'current') {
          nextActiveId = t.threadId;
          break;
        }
      }
      state = state.copyWith(
        session: updatedSession,
        activeThreadId: nextActiveId,
        isLoading: false,
      );
    } catch (e) {
      // Local fallback execution for offline mode
      int maxPrevOrder = 0;
      for (var t in currentSession.questionThreads) {
        if (t.status == 'previous' && t.sortOrder > maxPrevOrder) {
          maxPrevOrder = t.sortOrder;
        }
      }
      final newSortOrder = maxPrevOrder + 1;

      String? nextUpcomingId;
      final updatedThreads = currentSession.questionThreads.map((t) {
        if (t.threadId == currentThreadId) {
          return t.copyWith(status: 'previous', sortOrder: newSortOrder);
        }
        return t;
      }).toList();

      for (var t in updatedThreads) {
        if (t.status == 'upcoming') {
          nextUpcomingId = t.threadId;
          break;
        }
      }

      final finalThreads = updatedThreads.map((t) {
        if (nextUpcomingId != null && t.threadId == nextUpcomingId) {
          return t.copyWith(status: 'current');
        }
        return t;
      }).toList();

      state = state.copyWith(
        session: SessionModel(
          sessionId: currentSession.sessionId,
          questionThreads: finalThreads,
        ),
        activeThreadId: nextUpcomingId ?? '',
        isLoading: false,
      );
    }
  }

  Future<void> processTextInput(String text) async {
    if (text.trim().isEmpty) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final currentThreadId = state.activeThreadId;
      final currentSession = state.session;
      if (currentSession == null) throw Exception('No session active');

      final rawTranscript = text.trim();

      AnswerEntryModel newAnswer;
      try {
        await _apiService.continueChat(
          sessionId: currentSession.sessionId,
          threadId: currentThreadId,
          e4bTranscript: rawTranscript,
        );
        final freshSession = await _apiService.getSession(currentSession.sessionId);
        state = state.copyWith(session: freshSession, isLoading: false);
        return;
      } catch (e) {
        final activeT = state.activeThread;
        final nextSeq = (activeT?.answers.length ?? 0) + 1;

        newAnswer = AnswerEntryModel(
          seq: nextSeq,
          e4bTranscript: rawTranscript,
          gemma12bOutput: rawTranscript,
          localLanguageBaseline: LocalLanguageBaselineModel(
            languageCode: state.selectedLanguage,
            transcript: rawTranscript,
            status: 'COMPILED',
          ),
          corporateEnglishBaseline: CorporateEnglishBaselineModel(
            languageCode: 'en-US',
            transcript: rawTranscript,
            status: 'READY',
            editable: true,
          ),
          recordedAt: DateTime.now().toIso8601String(),
        );
      }

      final updatedThreads = currentSession.questionThreads.map((t) {
        if (t.threadId == currentThreadId) {
          final updatedAnswers = List<AnswerEntryModel>.from(t.answers)..add(newAnswer);
          return t.copyWith(answers: updatedAnswers);
        }
        return t;
      }).toList();

      state = state.copyWith(
        session: SessionModel(
          sessionId: currentSession.sessionId,
          questionThreads: updatedThreads,
        ),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error processing input: $e',
      );
    }
  }

  Future<void> processRecordedAudio(String audioFilePath) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final currentThreadId = state.activeThreadId;
      final currentSession = state.session;

      if (currentSession == null) {
        throw Exception('No session active');
      }

      // 1. Transcribe actual spoken voice audio recorded on phone
      String rawTranscript;
      try {
        rawTranscript = await _apiService.transcribeAudioFile(audioFilePath, languageCode: state.selectedLanguage);
      } catch (_) {
        final e4bResult = await _e4bService.transcribeAudio(audioFilePath);
        rawTranscript = e4bResult.transcript;
      }

      // 2. Refine transcript and append new answer entry back to the active thread
      AnswerEntryModel newAnswer;
      try {
        await _apiService.continueChat(
          sessionId: currentSession.sessionId,
          threadId: currentThreadId,
          e4bTranscript: rawTranscript,
        );
        final freshSession = await _apiService.getSession(currentSession.sessionId);
        state = state.copyWith(session: freshSession, isLoading: false);
        return;
      } catch (e) {
        final activeT = state.activeThread;
        final nextSeq = (activeT?.answers.length ?? 0) + 1;

        newAnswer = AnswerEntryModel(
          seq: nextSeq,
          e4bTranscript: rawTranscript,
          gemma12bOutput: rawTranscript,
          localLanguageBaseline: LocalLanguageBaselineModel(
            languageCode: state.selectedLanguage,
            transcript: rawTranscript,
            status: 'COMPILED',
          ),
          corporateEnglishBaseline: CorporateEnglishBaselineModel(
            languageCode: 'en-US',
            transcript: rawTranscript,
            status: 'READY',
            editable: true,
          ),
          recordedAt: DateTime.now().toIso8601String(),
        );
      }

      final updatedThreads = currentSession.questionThreads.map((t) {
        if (t.threadId == currentThreadId) {
          final updatedAnswers = List<AnswerEntryModel>.from(t.answers)..add(newAnswer);
          return t.copyWith(answers: updatedAnswers);
        }
        return t;
      }).toList();

      final updatedSession = SessionModel(
        sessionId: currentSession.sessionId,
        questionThreads: updatedThreads,
      );

      state = state.copyWith(
        session: updatedSession,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error processing mobile voice input: $e',
      );
    }
  }
}


final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(
    ref.read(apiServiceProvider),
    ref.read(e4bServiceProvider),
  );
});
