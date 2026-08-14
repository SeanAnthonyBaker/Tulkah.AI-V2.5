import 'dart:convert';

class LocalLanguageBaselineModel {
  final String languageCode;
  final String transcript;
  final String? compiledAudioUrl;
  final int chunkCount;
  final double totalDurationSeconds;
  final String status;

  LocalLanguageBaselineModel({
    required this.languageCode,
    required this.transcript,
    this.compiledAudioUrl,
    this.chunkCount = 0,
    this.totalDurationSeconds = 0.0,
    required this.status,
  });

  factory LocalLanguageBaselineModel.fromJson(Map<String, dynamic> json) {
    return LocalLanguageBaselineModel(
      languageCode: json['language_code'] as String? ?? 'auto',
      transcript: json['transcript'] as String? ?? '',
      compiledAudioUrl: json['compiled_audio_url'] as String?,
      chunkCount: json['chunk_count'] as int? ?? 0,
      totalDurationSeconds: (json['total_duration_seconds'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'RECORDING',
    );
  }

  Map<String, dynamic> toJson() => {
        'language_code': languageCode,
        'transcript': transcript,
        'compiled_audio_url': compiledAudioUrl,
        'chunk_count': chunkCount,
        'total_duration_seconds': totalDurationSeconds,
        'status': status,
      };
}

class CorporateEnglishBaselineModel {
  final String languageCode;
  final String transcript;
  final String status;
  final bool editable;
  final String? translatedAt;

  CorporateEnglishBaselineModel({
    required this.languageCode,
    required this.transcript,
    required this.status,
    required this.editable,
    this.translatedAt,
  });

  factory CorporateEnglishBaselineModel.fromJson(Map<String, dynamic> json) {
    return CorporateEnglishBaselineModel(
      languageCode: json['language_code'] as String? ?? 'en-US',
      transcript: json['transcript'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      editable: json['editable'] as bool? ?? false,
      translatedAt: json['translated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'language_code': languageCode,
        'transcript': transcript,
        'status': status,
        'editable': editable,
        'translated_at': translatedAt,
      };
}

class AnswerEntryModel {
  final int seq;
  final String e4bTranscript;
  final String gemma12bOutput;
  final String? ttsAudioPath;
  final LocalLanguageBaselineModel? localLanguageBaseline;
  final CorporateEnglishBaselineModel? corporateEnglishBaseline;
  final String recordedAt;

  AnswerEntryModel({
    required this.seq,
    required this.e4bTranscript,
    required this.gemma12bOutput,
    this.ttsAudioPath,
    this.localLanguageBaseline,
    this.corporateEnglishBaseline,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'e4b_transcript': e4bTranscript,
        'gemma12b_output': gemma12bOutput,
        'tts_audio_path': ttsAudioPath,
        'local_language_baseline': localLanguageBaseline?.toJson(),
        'corporate_english_baseline': corporateEnglishBaseline?.toJson(),
        'recorded_at': recordedAt,
      };

  factory AnswerEntryModel.fromJson(Map<String, dynamic> json) {
    return AnswerEntryModel(
      seq: json['seq'] as int,
      e4bTranscript: json['e4b_transcript'] as String? ?? '',
      gemma12bOutput: json['gemma12b_output'] as String? ?? '',
      ttsAudioPath: json['tts_audio_path'] as String?,
      localLanguageBaseline: json['local_language_baseline'] != null
          ? LocalLanguageBaselineModel.fromJson(json['local_language_baseline'] as Map<String, dynamic>)
          : null,
      corporateEnglishBaseline: json['corporate_english_baseline'] != null
          ? CorporateEnglishBaselineModel.fromJson(json['corporate_english_baseline'] as Map<String, dynamic>)
          : null,
      recordedAt: json['recorded_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}

class QuestionThreadModel {
  final String threadId;
  final String questionText;
  final String status; // "previous" | "current" | "upcoming"
  final int sortOrder;
  final List<AnswerEntryModel> answers;

  QuestionThreadModel({
    required this.threadId,
    required this.questionText,
    required this.status,
    required this.sortOrder,
    required this.answers,
  });

  QuestionThreadModel copyWith({
    String? threadId,
    String? questionText,
    String? status,
    int? sortOrder,
    List<AnswerEntryModel>? answers,
  }) {
    return QuestionThreadModel(
      threadId: threadId ?? this.threadId,
      questionText: questionText ?? this.questionText,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      answers: answers ?? this.answers,
    );
  }

  Map<String, dynamic> toJson() => {
        'thread_id': threadId,
        'question_text': questionText,
        'status': status,
        'sort_order': sortOrder,
        'answers': answers.map((a) => a.toJson()).toList(),
      };

  factory QuestionThreadModel.fromJson(Map<String, dynamic> json) {
    var rawAnswers = json['answers'] as List<dynamic>? ?? [];
    List<AnswerEntryModel> parsedAnswers =
        rawAnswers.map((a) => AnswerEntryModel.fromJson(a as Map<String, dynamic>)).toList();
    // Enforce recorded sequence ordering
    parsedAnswers.sort((a, b) => a.seq.compareTo(b.seq));

    return QuestionThreadModel(
      threadId: json['thread_id'] as String,
      questionText: json['question_text'] as String,
      status: json['status'] as String? ?? 'upcoming',
      sortOrder: json['sort_order'] as int? ?? 0,
      answers: parsedAnswers,
    );
  }
}

class SessionModel {
  final String sessionId;
  final List<QuestionThreadModel> questionThreads;

  SessionModel({
    required this.sessionId,
    required this.questionThreads,
  });

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'question_threads': questionThreads.map((t) => t.toJson()).toList(),
      };

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    var rawThreads = json['question_threads'] as List<dynamic>? ?? [];
    List<QuestionThreadModel> threads =
        rawThreads.map((t) => QuestionThreadModel.fromJson(t as Map<String, dynamic>)).toList();
    threads.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return SessionModel(
      sessionId: json['session_id'] as String? ?? 'sess_default',
      questionThreads: threads,
    );
  }
}

