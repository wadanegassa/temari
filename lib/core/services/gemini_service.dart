import 'dart:async';
import 'dart:convert';

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

  Uri get _generateUrl => Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
  );
  Uri get _streamUrl => Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$_model:streamGenerateContent',
  );

  bool get hasKey => _apiKey.isNotEmpty;

  void _requireApiKey() {
    if (!hasKey) {
      throw StateError('Gemini API key is not configured. AI features require an online connection.');
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

  Stream<String> explainText({
    required String content,
    required String language,
    String? subjectName,
  }) {
    _requireApiKey();

    final prompt = '''
You are Temari, an expert academic tutor for Ethiopian university students.
$_explanationLangInstruction

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
You are Temari, an expert academic tutor for Ethiopian university students.
$_explanationLangInstruction

Carefully examine this image. It contains study material — textbook pages, notes, diagrams, or formulas.
Explain everything you see: define terms, break down formulas, describe diagrams.
Write in clear paragraphs. No markdown symbols.
Subject context: ${subjectName ?? 'General'}
'''
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
You are Temari, an expert academic tutor for Ethiopian university students.
$_explanationLangInstruction

Read this PDF document carefully and explain its core content to a university student.
Cover: main concepts, key definitions, important theories, and practical applications.
Write in clear paragraphs. No markdown symbols.
Subject context: ${subjectName ?? 'General'}
'''
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
    final prompt = '''
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
    final prompt = '''
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
    final prompt = '''
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
    return decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> generateMindMap({
    required String content,
    String language = 'en',
  }) async {
    _requireApiKey();

    final langInstruction = _langInstruction(language);
    final prompt = '''
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
        .map((m) => '${m['role'] == 'user' ? 'Student' : 'Temari'}: ${m['text']}')
        .join('\n');

    final prompt = '''
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
        .map((m) => '${m['role'] == 'user' ? 'Student' : 'Temari'}: ${m['text']}')
        .join('\n');

    final prompt = '''
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

  static const String _explanationLangInstruction = '''
CRITICAL: You must provide your complete response in THREE languages in the following exact format:
[ENGLISH]
<Provide the full explanation in English here>

[አማርኛ]
<Provide the full explanation in Amharic (አማርኛ) here>

[AFAAN OROMOO]
<Provide the full explanation in Afaan Oromo here>

Make sure all three language versions are complete, clear, and easy to understand for university students. Do not mix them in a single paragraph; write each section completely in its respective language. No markdown formatting symbols.
''';

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
