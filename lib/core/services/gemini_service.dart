import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_env.dart';

/// Google Gemini multimodal client for online AI generation.
class GeminiService {
  GeminiService({String? apiKey, String? model})
    : _apiKey = apiKey ?? AppEnv.geminiApiKey,
      _modelOverride = model;

  final String? _modelOverride;
  final String _apiKey;

  String get _model => _modelOverride ?? AppEnv.geminiModel;

  bool get hasKey => _apiKey.isNotEmpty;

  void _requireApiKey() {
    if (!hasKey) {
      throw StateError(
        'Gemini API key is not configured. AI features require an online connection.',
      );
    }
  }

  /// Helper to extract clean JSON blocks from conversational text.
  String _extractJsonSubstring(String text) {
    final firstArray = text.indexOf('[');
    final firstObject = text.indexOf('{');

    if (firstArray != -1 && (firstObject == -1 || firstArray < firstObject)) {
      final lastArray = text.lastIndexOf(']');
      if (lastArray != -1 && lastArray > firstArray) {
        return text.substring(firstArray, lastArray + 1);
      }
    } else if (firstObject != -1) {
      final lastObject = text.lastIndexOf('}');
      if (lastObject != -1 && lastObject > firstObject) {
        return text.substring(firstObject, lastObject + 1);
      }
    }
    return text.replaceAll('```json', '').replaceAll('```', '').trim();
  }

  /// Parses the [ENGLISH], [አማርኛ], [AFAAN OROMOO] blocks into a Map.
  Map<String, String> parseMultiLanguageResponse(String text) {
    final map = <String, String>{};

    final enMatch = RegExp(
      r'\[ENGLISH\]\s*([\s\S]*?)(?=\[አማርኛ\]|\[AFAAN OROMOO\]|$)',
    );
    final amMatch = RegExp(
      r'\[አማርኛ\]\s*([\s\S]*?)(?=\[ENGLISH\]|\[AFAAN OROMOO\]|$)',
    );
    final omMatch = RegExp(
      r'\[AFAAN OROMOO\]\s*([\s\S]*?)(?=\[ENGLISH\]|\[አማርኛ\]|$)',
    );

    final enText = enMatch.firstMatch(text)?.group(1)?.trim();
    final amText = amMatch.firstMatch(text)?.group(1)?.trim();
    final omText = omMatch.firstMatch(text)?.group(1)?.trim();

    if (enText != null && enText.isNotEmpty) map['en'] = enText;
    if (amText != null && amText.isNotEmpty) map['am'] = amText;
    if (omText != null && omText.isNotEmpty) map['om'] = omText;

    return map;
  }

  /// Returns a language map that always contains the requested language.
  ///
  /// This supports both legacy triple-language responses and new
  /// single-language responses.
  Map<String, String> normalizeExplanationByLanguage({
    required String text,
    required String requestedLanguage,
  }) {
    final parsed = parseMultiLanguageResponse(text);
    final trimmed = text.trim();
    if (trimmed.isNotEmpty && !parsed.containsKey(requestedLanguage)) {
      parsed[requestedLanguage] = trimmed;
    }
    return parsed;
  }

  Stream<String> explainText({
    required String content,
    required String language,
    String? subjectName,
  }) {
    _requireApiKey();
    final langInstruction = _langInstruction(language);

    final prompt =
        '''
You are Temari, an expert academic tutor for Ethiopian university students.
$langInstruction

Subject context: ${subjectName ?? 'General'}

Explain the following study content clearly and thoroughly. 
Structure your explanation with: core concept first, detailed breakdown, real-world examples, key terms defined, and a brief summary at the end.
Write in flowing paragraphs. No markdown symbols like ** or ##. No bullet points unless listing sequential steps.

Content to explain:
$content
''';
    return _streamFromPrompt(prompt);
  }

  Stream<String> explainImage({
    required List<int> imageBytes,
    required String mimeType,
    required String language,
    String? subjectName,
    String? fileName,
  }) {
    _requireApiKey();
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
              'text':
                  '''
You are Temari, an expert academic tutor for Ethiopian university students.
$langInstruction

Carefully examine this image as study material and extract all important information.
Do not skip visible details. Read text, labels, formulas, tables, diagrams, arrows, legends, and annotations.
If parts are unclear, say what is uncertain and continue with what is readable.

Explain with this order:
1) what the material is about,
2) key concepts and definitions,
3) formulas/figures and how they work,
4) exam-focused takeaways and likely misunderstandings.

Write in clear paragraphs. No markdown symbols.
Subject context: ${subjectName ?? 'General'}
File name context: ${fileName ?? 'Unknown image'}
''',
            },
          ],
        },
      ],
      'generationConfig': {'temperature': 0.35},
    };
    return _streamFromBody(body);
  }

  Stream<String> explainPdf({
    required List<int> pdfBytes,
    required String language,
    String? subjectName,
    String? fileName,
  }) {
    _requireApiKey();
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
              'text':
                  '''
You are Temari, an expert academic tutor for Ethiopian university students.
$langInstruction

Read this PDF carefully and explain it in detail for university exam preparation.
Cover all major sections/pages that contain useful study content.
Do not skip formulas, examples, tables, headings, or definitions.

Explain with this structure:
1) high-level summary of the whole document,
2) section-by-section explanation of key points,
3) important definitions/theorems/formulas,
4) practical examples or applications,
5) concise exam revision checklist.

If any page text is not fully readable, state that clearly and continue with available content.
Write in clear paragraphs. No markdown symbols.
Subject context: ${subjectName ?? 'General'}
File name context: ${fileName ?? 'Unknown PDF'}
''',
            },
          ],
        },
      ],
      'generationConfig': {'temperature': 0.35},
    };
    return _streamFromBody(body);
  }

  Future<List<Map<String, String>>> generateFlashcards({
    required String content,
    required String language,
    int count = 6,
  }) async {
    _requireApiKey();

    final langInstruction = _langInstruction(language);
    final prompt =
        '''
You are Temari, an exam preparation AI.
$langInstruction

Based on this content, generate exactly $count high-quality flashcards for exam preparation.
Rules: questions must be specific and testable, answers 1-3 sentences, cover key facts/definitions/processes/theories, no repeated topics. Make sure the question and answer text values are written entirely in the requested language.

Return ONLY a JSON array. No preamble, no markdown, no backticks.
Format: [{"q": "question in the chosen language", "a": "answer in the chosen language"}]

Content:
$content
''';

    final response = await _singleResponse(prompt);
    final cleaned = _extractJsonSubstring(response);
    final decoded = jsonDecode(cleaned) as List<dynamic>;
    return decoded.map<Map<String, String>>((item) {
      final m = item as Map<String, dynamic>;
      return {
        'question': (m['q'] ?? m['question'] ?? '') as String,
        'answer': (m['a'] ?? m['answer'] ?? '') as String,
      };
    }).toList();
  }

  Future<List<String>> predictExamQuestions({
    required String content,
    required String language,
  }) async {
    _requireApiKey();

    final langInstruction = _langInstruction(language);
    final prompt =
        '''
You are Temari. Given this study content, predict 5 exam questions a university professor would likely ask.
$langInstruction
Make sure the predicted questions are written entirely in the requested language.
Return ONLY a JSON array of strings. No other text.

Content:
$content
''';

    final response = await _singleResponse(prompt);
    final cleaned = _extractJsonSubstring(response);
    final decoded = jsonDecode(cleaned) as List<dynamic>;
    return decoded.map<String>((e) => e.toString()).toList();
  }

  Future<List<Map<String, dynamic>>> generateQuiz({
    required String content,
    required String language,
  }) async {
    _requireApiKey();

    final langInstruction = _langInstruction(language);
    final prompt =
        '''
You are Temari. Based on the following study content, generate exactly 5 multiple choice questions for a quiz.
$langInstruction
Ensure the questions and options are written entirely in the requested language.

Return ONLY a JSON array. No preamble, no markdown, no backticks.
Format:
[
  {
    "question": "Question text?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0
  }
]

Content:
$content
''';

    final response = await _singleResponse(prompt);
    final cleaned = _extractJsonSubstring(response);
    final decoded = jsonDecode(cleaned) as List<dynamic>;
    return decoded
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> generateMindMap({
    required String content,
    String language = 'en',
  }) async {
    _requireApiKey();

    final langInstruction = _langInstruction(language);
    final prompt =
        '''
You are Temari. Generate a nested structure representing a conceptual mindmap based on this study content.
$langInstruction
Make sure all center, branch, and child text labels are written entirely in the requested language.

Rules:
Return ONLY a single JSON object. No preamble, no markdown.
Format:
{
  "center": "Core subject label in the chosen language",
  "branches": [
    {
      "label": "Branch label in the chosen language",
      "children": ["sub-topic 1 in the chosen language", "sub-topic 2 in the chosen language"]
    }
  ]
}

Content:
$content
''';

    final response = await _singleResponse(prompt);
    final cleaned = _extractJsonSubstring(response);
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  Stream<String> generalChatStream({
    required List<Map<String, String>> messageHistory,
    required String userQuestion,
    required String language,
  }) {
    _requireApiKey();

    final langInstruction = _langInstruction(language);
    final history = messageHistory
        .map(
          (m) => '${m['role'] == 'user' ? 'Student' : 'Temari'}: ${m['text']}',
        )
        .join('\n');

    final prompt =
        '''
You are Temari, an expert academic tutor for Ethiopian university students.
$langInstruction

--- CONVERSATION SO FAR ---
$history

--- STUDENT'S QUESTION ---
$userQuestion

Answer the student's question clearly, helpfully, and with academic focus. Be concise and write in flowing paragraphs. No markdown.
''';
    return _streamFromPrompt(prompt);
  }

  Stream<String> chatAboutNote({
    required String noteContent,
    required String aiExplanation,
    required List<Map<String, String>> messageHistory,
    required String userQuestion,
    required String language,
  }) {
    _requireApiKey();

    final langInstruction = _langInstruction(language);
    final history = messageHistory
        .map(
          (m) => '${m['role'] == 'user' ? 'Student' : 'Temari'}: ${m['text']}',
        )
        .join('\n');

    final prompt =
        '''
You are helping a student understand a specific piece of study material.
$langInstruction

--- STUDY MATERIAL ---
$noteContent

--- AI EXPLANATION ALREADY GIVEN ---
$aiExplanation

--- CONVERSATION SO FAR ---
$history

--- STUDENT'S NEW QUESTION ---
$userQuestion

Answer the student's question based on the study material above. Be clear, helpful, and concise.
If the question is unrelated to the material, gently bring focus back.
''';
    return _streamFromPrompt(prompt);
  }

  String _langInstruction(String lang) {
    switch (lang) {
      case 'am':
        return 'CRITICAL: Respond entirely in Amharic (አማርኛ). Use simple, clear Amharic suitable for university students.';
      case 'om':
        return 'CRITICAL: Respond entirely in Afaan Oromo. Use simple, clear Afaan Oromo suitable for university students.';
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
      'generationConfig': {'temperature': 0.35, 'maxOutputTokens': 2048},
    };
    return _streamFromBody(body);
  }

  Stream<String> _streamFromBody(Map<String, dynamic> body) async* {
    // Some models may not be available for the v1beta API or the
    // `generateContent` method. If the configured model is not supported
    // we retry against a small list of known working model names.
    final candidates = <String>[_model, 'gemini-3.5-flash', 'gemini-2.5-flash'];
    final client = http.Client();
    try {
      for (var i = 0; i < candidates.length; i++) {
        final modelName = candidates[i];
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:streamGenerateContent',
        ).replace(queryParameters: {'key': _apiKey, 'alt': 'sse'});
        try {
          final request = http.Request('POST', url)
            ..headers['Content-Type'] = 'application/json'
            ..body = jsonEncode(body);
          final response = await client.send(request);
          if (response.statusCode != 200) {
            final err = await response.stream.bytesToString();
            final lower = err.toLowerCase();
            final shouldRetry =
                response.statusCode == 404 ||
                lower.contains('not found') ||
                lower.contains('not supported') ||
                lower.contains('is not found');
            if (shouldRetry && i < candidates.length - 1) {
              continue;
            }
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
        return;
        } catch (e) {
          if (e is SocketException) {
            throw GeminiException(503, '{"error": {"message": "No internet connection. Please check your network and try again."}}');
          }
          rethrow;
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
    // Try the configured model first, then fall back to known working models
    final candidates = <String>[_model, 'gemini-3.5-flash', 'gemini-2.5-flash'];
    for (var i = 0; i < candidates.length; i++) {
      final modelName = candidates[i];
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent',
      ).replace(queryParameters: {'key': _apiKey});

      try {
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

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return _extractText(json) ?? '';
        }

        final bodyStr = response.body.toLowerCase();
        final shouldRetry =
            response.statusCode == 404 ||
            bodyStr.contains('not found') ||
            bodyStr.contains('not supported') ||
            bodyStr.contains('is not found');

        if (!shouldRetry || i == candidates.length - 1) {
          throw GeminiException(response.statusCode, response.body);
        }
        // otherwise, try next candidate model
      } catch (e) {
        if (e is SocketException) {
          throw GeminiException(503, '{"error": {"message": "No internet connection. Please check your network and try again."}}');
        }
        rethrow;
      }
      // otherwise, try next candidate model
    }
    // unreachable, but required to satisfy return type
    throw GeminiException(500, 'No response from generative API');
  }
}

class GeminiException implements Exception {
  GeminiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  String get cleanMessage {
    try {
      final parsed = jsonDecode(body);
      final msg = parsed['error']?['message'];
      if (msg != null && msg.toString().isNotEmpty) {
        return msg.toString();
      }
    } catch (_) {}
    return 'Status $statusCode: $body';
  }

  @override
  String toString() => 'GeminiException($statusCode): $body';
}
