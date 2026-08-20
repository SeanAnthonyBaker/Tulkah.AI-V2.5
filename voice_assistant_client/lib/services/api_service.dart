import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/session_models.dart';

class ApiService {
  String baseUrl;

  ApiService({this.baseUrl = 'http://127.0.0.1:8080'});

  void updateBaseUrl(String newUrl) {
    if (!newUrl.startsWith('http://') && !newUrl.startsWith('https://')) {
      baseUrl = 'http://$newUrl';
    } else {
      baseUrl = newUrl;
    }
  }

  Future<SessionModel> getSession(String sessionId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/v1/session/$sessionId'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      return SessionModel.fromJson(jsonBody);
    } else {
      throw Exception('Failed to fetch session: ${response.statusCode}');
    }
  }

  Future<SessionModel> resetSession(String sessionId) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/v1/session/$sessionId/reset'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      return SessionModel.fromJson(jsonBody);
    } else {
      throw Exception('Failed to reset session: ${response.statusCode}');
    }
  }

  Future<SessionModel> acceptThread(String sessionId, String threadId) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/v1/session/$sessionId/thread/$threadId/accept'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      return SessionModel.fromJson(jsonBody);
    } else {
      throw Exception('Failed to accept thread: ${response.statusCode}');
    }
  }

  Future<SessionModel> clearThread(String sessionId, String threadId) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/v1/session/$sessionId/thread/$threadId/clear'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      return SessionModel.fromJson(jsonBody);
    } else {
      throw Exception('Failed to clear thread: ${response.statusCode}');
    }
  }

  Future<SessionModel> deleteLastSegment(String sessionId, String threadId) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/v1/session/$sessionId/thread/$threadId/delete-last-segment'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      return SessionModel.fromJson(jsonBody);
    } else {
      throw Exception('Failed to delete last segment: ${response.statusCode}');
    }
  }

  Future<SessionModel> adjustAnswer(String sessionId, String threadId, String instruction) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/v1/session/$sessionId/thread/$threadId/adjust?instruction=${Uri.encodeComponent(instruction)}'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      return SessionModel.fromJson(jsonBody);
    } else {
      throw Exception('Failed to adjust answer: ${response.statusCode}');
    }
  }

  Future<SessionModel> generateAIAnswer(String sessionId, String threadId) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/v1/session/$sessionId/thread/$threadId/ai-answer'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      return SessionModel.fromJson(jsonBody);
    } else {
      throw Exception('Failed to generate AI answer: ${response.statusCode}');
    }
  }

  Future<SessionModel> streamAIAnswer(
    String sessionId,
    String threadId,
    int sentenceCount,
    Function(String accumulatedText) onChunk,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/api/v1/session/$sessionId/thread/$threadId/ai-answer/stream?sentence_count=$sentenceCount'),
      );
      request.headers['Content-Type'] = 'application/json';

      final response = await client.send(request);
      if (response.statusCode == 200) {
        String accumulated = "";
        await response.stream.transform(utf8.decoder).forEach((chunk) {
          accumulated += chunk;
          onChunk(accumulated);
        });
        return await getSession(sessionId);
      } else {
        throw Exception('Stream failed with status: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  Future<String> transcribeAudioFile(String audioFilePath, {String languageCode = 'auto'}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/audio/transcribe?language_code=$languageCode');
      final request = http.MultipartRequest('POST', uri);

      if (kIsWeb || audioFilePath.startsWith('blob:') || audioFilePath.startsWith('http')) {
        final audioResponse = await http.get(Uri.parse(audioFilePath));
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          audioResponse.bodyBytes,
          filename: 'recorded_audio.wav',
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', audioFilePath));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);
        final transcript = jsonBody['transcript'] as String?;
        if (transcript != null && transcript.trim().isNotEmpty && transcript != 'Voice input recorded.') {
          return transcript.trim();
        }
        throw Exception('No spoken words detected in audio recording');
      } else {
        throw Exception('Server error during transcription (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('transcribeAudioFile error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> streamAudioChunk({
    required String sessionId,
    required String threadId,
    required int chunkSeq,
    required String audioFilePath,
    String languageCode = 'auto',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/audio/stream-chunk?session_id=$sessionId&thread_id=$threadId&chunk_seq=$chunkSeq&language_code=$languageCode');
      final request = http.MultipartRequest('POST', uri);

      if (kIsWeb || audioFilePath.startsWith('blob:') || audioFilePath.startsWith('http')) {
        final audioResponse = await http.get(Uri.parse(audioFilePath));
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          audioResponse.bodyBytes,
          filename: 'chunk_$chunkSeq.wav',
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', audioFilePath));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        return {'status': 'error', 'local_transcript': 'Audio chunk recorded.'};
      }
    } catch (e) {
      return {'status': 'error', 'local_transcript': 'Audio chunk recorded.'};
    }
  }

  Future<AnswerEntryModel> continueChat({
    required String sessionId,
    required String threadId,
    required String e4bTranscript,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/v1/chat/continue'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'session_id': sessionId,
            'thread_id': threadId,
            'e4b_transcript': e4bTranscript,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      return AnswerEntryModel.fromJson(jsonBody);
    } else {
      throw Exception('Chat continue failed: ${response.statusCode} - ${response.body}');
    }
  }



  Future<String> synthesizeTts(String threadId, String text) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/v1/tts/synthesize?thread_id=$threadId&text=${Uri.encodeComponent(text)}'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);
        final relativeUrl = jsonBody['audio_url'] ?? '';
        return relativeUrl.startsWith('http') ? relativeUrl : '$baseUrl$relativeUrl';
      }
      return '';
    } catch (_) {
      return '';
    }
  }
}


