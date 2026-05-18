import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_env.dart';

/// Google Gemini multimodal client (direct HTTP, no server).
class GeminiService {
  GeminiService({String? apiKey}) : _apiKey = apiKey ?? AppEnv.geminiApiKey;

  static const _model = 'gemini-3.1-flash-lite';
  static final _generateUrl = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
  );
  static final _streamUrl = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$_model:streamGenerateContent',
  );

  final String _apiKey;

  bool get hasKey => _apiKey.isNotEmpty;

  Stream<String> explainText({
    required String content,
    required String language,
    String? subjectName,
  }) {
    final langInstruction = _langInstruction(language);
    final prompt = '''
You are Temari, an expert academic tutor for Ethiopian university students.
$langInstruction

Subject context: ${subjectName ?? 'General'}

Explain the following content clearly and deeply. Use simple language,
real-world examples the student can relate to, and break it into logical sections.
Do not use markdown symbols like ** or ##. Write in clean paragraphs.
If there are key terms, define them clearly. End with a one-paragraph summary.

Content:
$content
''';
    return _streamFromPrompt(prompt);
  }

  Stream<String> explainImage({
    required List<int> imageBytes,
    required String mimeType,
    required String language,
    String? subjectName,
  }) {
    final langInstruction = _langInstruction(language);
    final base64Image = base64Encode(imageBytes);
    final body = {
      'contents': [
        {
          'parts': [
            {
              'inline_data': {'mime_type': mimeType, 'data': base64Image},
            },
            {
              'text': '''
You are Temari, an expert academic tutor.
$langInstruction

Look at this image carefully. It may contain textbook pages, handwritten notes,
diagrams, or formulas. Explain all the content you see in a clear, student-friendly
way. Define key terms. Break down any formulas or diagrams.
Do not use markdown symbols. Write in clean paragraphs.
Subject context: ${subjectName ?? 'General'}
'''
            },
          ],
        },
      ],
      'generationConfig': {'temperature': 0.3},
    };
    return _streamFromBody(body);
  }

  Stream<String> explainPdf({
    required List<int> pdfBytes,
    required String language,
    String? subjectName,
  }) {
    final langInstruction = _langInstruction(language);
    final base64Pdf = base64Encode(pdfBytes);
    final body = {
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': 'application/pdf',
                'data': base64Pdf,
              },
            },
            {
              'text': '''
You are Temari, an expert academic tutor.
$langInstruction

Read this PDF document carefully. Explain its core content to a university student.
Cover the main concepts, key definitions, important points, and any theories or frameworks.
Use student-friendly language. Write in clean paragraphs without markdown symbols.
Subject: ${subjectName ?? 'General'}
'''
            },
          ],
        },
      ],
      'generationConfig': {'temperature': 0.3},
    };
    return _streamFromBody(body);
  }

  Future<List<Map<String, String>>> generateFlashcards({
    required String content,
    required String language,
    int count = 10,
  }) async {
    final langInstruction = _langInstruction(language);
    final prompt = '''
You are Temari. Based on the following content, generate exactly $count flashcards for exam preparation.
$langInstruction

Rules:
- Each question must be specific and testable
- Answers must be concise (1-3 sentences max)
- Focus on definitions, concepts, processes, and key facts
- Do not repeat similar questions

Return ONLY a JSON array. No other text. No markdown. Example format:
[{"q": "What is photosynthesis?", "a": "The process by which plants convert sunlight into glucose."}]

Content:
$content
''';

    final response = await _singleResponse(prompt);
    try {
      final cleaned =
          response.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(cleaned) as List<dynamic>;
      return decoded.map<Map<String, String>>((item) {
        final m = item as Map<String, dynamic>;
        return {
          'question': (m['q'] ?? m['question']) as String,
          'answer': (m['a'] ?? m['answer']) as String,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> predictExamQuestions({
    required String content,
    required String language,
  }) async {
    final langInstruction = _langInstruction(language);
    final prompt = '''
You are Temari. Based on this study content, predict 5 likely exam questions a university professor might ask.
$langInstruction
Return ONLY a JSON array of strings. Example: ["Question 1", "Question 2"]
Content: $content
''';
    final response = await _singleResponse(prompt);
    try {
      final cleaned =
          response.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(cleaned) as List<dynamic>;
      return decoded.map((q) => q.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  String _langInstruction(String lang) {
    switch (lang) {
      case 'am':
        return 'IMPORTANT: Respond entirely in Amharic (አማርኛ). Use clear, simple Amharic that university students understand.';
      case 'om':
        return 'IMPORTANT: Respond entirely in Afaan Oromo. Use clear, simple Afaan Oromo that university students understand.';
      default:
        return 'Respond in English.';
    }
  }

  Stream<String> _streamFromPrompt(String prompt) {
    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {'temperature': 0.4},
    };
    return _streamFromBody(body);
  }

  Stream<String> _streamFromBody(Map<String, dynamic> body) async* {
    final url = _streamUrl.replace(queryParameters: {
      'key': _apiKey,
      'alt': 'sse',
    });
    final client = http.Client();
    try {
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final err = await response.stream.bytesToString();
        throw GeminiException(response.statusCode, err);
      }
      var accumulated = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data.isEmpty || data == '[DONE]') continue;
          try {
            final map = jsonDecode(data) as Map<String, dynamic>;
            final text = _extractText(map);
            if (text != null && text.isNotEmpty) {
              if (text.startsWith(accumulated)) {
                final delta = text.substring(accumulated.length);
                accumulated = text;
                if (delta.isNotEmpty) yield delta;
              } else {
                accumulated += text;
                yield text;
              }
            }
          } catch (_) {
            // ignore malformed sse frames
          }
        }
      }
    } finally {
      client.close();
    }
  }

  String? _extractText(Map<String, dynamic> json) {
    final parts = json['candidates']?[0]?['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) return null;
    final first = parts[0];
    if (first is Map && first['text'] is String) return first['text'] as String;
    return null;
  }

  Future<String> _singleResponse(String prompt) async {
    final url = _generateUrl.replace(queryParameters: {'key': _apiKey});
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'temperature': 0.3},
      }),
    );
    if (response.statusCode != 200) {
      throw GeminiException(response.statusCode, response.body);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _extractText(json) ?? '';
  }
}

class GeminiException implements Exception {
  GeminiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'GeminiException($statusCode): $body';
}
