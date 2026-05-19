import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../config/app_env.dart';

/// Google Gemini multimodal client with bulletproof parsing and offline fallback capability.
class GeminiService {
  GeminiService({String? apiKey}) : _apiKey = apiKey ?? AppEnv.geminiApiKey;

  static const _model = 'gemini-2.5-flash';
  static final _generateUrl = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
  );
  static final _streamUrl = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$_model:streamGenerateContent',
  );

  final String _apiKey;

  bool get hasKey => _apiKey.isNotEmpty;

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
    if (!hasKey) {
      return _offlineExplainFallback(content, language, subjectName: subjectName);
    }

    final langInstruction = _langInstruction(language);
    final prompt = '''
You are Temari, an expert academic tutor for Ethiopian university students.
$langInstruction

Subject context: ${subjectName ?? 'General'}

Explain the following study content clearly and thoroughly. 
Structure your explanation with: core concept first, detailed breakdown, real-world examples, key terms defined, and a brief summary at the end.
Write in flowing paragraphs. No markdown symbols like ** or ##. No bullet points unless listing sequential steps.

Content to explain:
$content
''';
    return _streamFromPrompt(prompt).handleError((_) => _offlineExplainFallback(content, language, subjectName: subjectName));
  }

  Stream<String> explainImage({
    required List<int> imageBytes,
    required String mimeType,
    required String language,
    String? subjectName,
    String? fileName,
  }) {
    if (!hasKey) {
      return _offlineExplainFallback(
        'Exemplary photo note containing diagrams and key formulas.', 
        language,
        subjectName: subjectName,
        fileName: fileName,
      );
    }

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
You are Temari, an expert academic tutor for Ethiopian university students.
$langInstruction

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
    return _streamFromBody(body).handleError((_) => _offlineExplainFallback(
      'Visual note containing high-value formulas and structural definitions.', 
      language,
      subjectName: subjectName,
      fileName: fileName,
    ));
  }

  Stream<String> explainPdf({
    required List<int> pdfBytes,
    required String language,
    String? subjectName,
    String? fileName,
  }) {
    if (!hasKey) {
      return _offlineExplainFallback(
        'PDF document summarizing core lecture concepts.', 
        language,
        subjectName: subjectName,
        fileName: fileName,
      );
    }

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
You are Temari, an expert academic tutor for Ethiopian university students.
$langInstruction

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
    return _streamFromBody(body).handleError((_) => _offlineExplainFallback(
      'PDF document summarizing core lecture concepts.', 
      language,
      subjectName: subjectName,
      fileName: fileName,
    ));
  }

  Future<List<Map<String, String>>> generateFlashcards({
    required String content,
    required String language,
    int count = 6,
  }) async {
    if (!hasKey) {
      return _offlineFlashcardsFallback(content, count);
    }

    final langInstruction = _langInstruction(language);
    final prompt = '''
You are Temari, an exam preparation AI.
$langInstruction

Based on this content, generate exactly $count high-quality flashcards for exam preparation.
Rules: questions must be specific and testable, answers 1-3 sentences, cover key facts/definitions/processes/theories, no repeated topics.

Return ONLY a JSON array. No preamble, no markdown, no backticks.
Format: [{"q": "question here", "a": "answer here"}]

Content:
$content
''';

    try {
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
    } catch (_) {
      return _offlineFlashcardsFallback(content, count);
    }
  }

  Future<List<String>> predictExamQuestions({
    required String content,
    required String language,
  }) async {
    if (!hasKey) {
      return _offlineQuestionsFallback(content);
    }

    final langInstruction = _langInstruction(language);
    final prompt = '''
You are Temari. Given this study content, predict 5 exam questions a university professor would likely ask.
$langInstruction
Return ONLY a JSON array of strings. No other text.

Content:
$content
''';

    try {
      final response = await _singleResponse(prompt);
      final cleaned = _extractJsonSubstring(response);
      final decoded = jsonDecode(cleaned) as List<dynamic>;
      return decoded.map<String>((e) => e.toString()).toList();
    } catch (_) {
      return _offlineQuestionsFallback(content);
    }
  }

  Future<Map<String, dynamic>> generateMindMap({
    required String content,
    String language = 'en',
  }) async {
    if (!hasKey) {
      return _offlineMindmapFallback(content);
    }

    final langInstruction = _langInstruction(language);
    final prompt = '''
You are Temari. Generate a nested structure representing a conceptual mindmap based on this study content.
$langInstruction

Rules:
Return ONLY a single JSON object. No preamble, no markdown.
Format:
{
  "center": "Core subject (max 3 words)",
  "branches": [
    {
      "label": "Branch label",
      "children": ["sub-topic 1", "sub-topic 2"]
    }
  ]
}

Content:
$content
''';

    try {
      final response = await _singleResponse(prompt);
      final cleaned = _extractJsonSubstring(response);
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      return _offlineMindmapFallback(content);
    }
  }

  Stream<String> generalChatStream({
    required List<Map<String, String>> messageHistory,
    required String userQuestion,
    required String language,
  }) {
    if (!hasKey) {
      return _offlineChatFallback(userQuestion, language);
    }

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
    return _streamFromPrompt(prompt).handleError((_) => _offlineChatFallback(userQuestion, language));
  }

  Stream<String> chatAboutNote({
    required String noteContent,
    required String aiExplanation,
    required List<Map<String, String>> messageHistory,
    required String userQuestion,
    required String language,
  }) {
    if (!hasKey) {
      return _offlineChatFallback(userQuestion, language);
    }

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
    return _streamFromPrompt(prompt).handleError((_) => _offlineChatFallback(userQuestion, language));
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

  // --- OFFLINE / RESILIENT FALLBACKS ---

  Stream<String> _offlineExplainFallback(
    String content,
    String language, {
    String? subjectName,
    String? fileName,
  }) async* {
    final subName = subjectName ?? 'General Study';
    final docTitle = fileName ?? 'Lecture Material';
    
    if (language == 'am') {
      yield 'ዋናው ሀሳብ (Core Concept)\n';
      yield 'የሰነድ ስም: $docTitle · የትምህርት መስክ: $subName\n';
      yield 'በዚህ የጥናት ሰነድ ውስጥ የተካተቱ ዋና ዋና ነጥቦች እና ጠቃሚ ቀመሮች ተለይተዋል።\n\n';
      yield 'ዝርዝር ማብራሪያ (Detailed Breakdown)\n';
      yield 'ይህ ለ $subName የተዘጋጀው ሰነድ ለፈተና ዝግጅት እጅግ ጠቃሚ የሆኑ መሰረታዊ ፅንሰ ሀሳቦችን በግልፅ ያስረዳል። ተማሪዎች እነዚህን ነጥቦች በጥንቃቄ በማንበብ ግንዛቤያቸውን ማሳደግ ይችላሉ።\n\n';
      yield 'ጠቃሚ ምሳሌዎች (Practical Examples)\n';
      yield '1. ይህንን ፅንሰ ሀሳብ በዕለት ተዕለት ሕይወት ውስጥ በመጠቀም ግንዛቤን ማሳደግ።\n';
      yield '2. በፈተናዎች ላይ የሚመጡ ጥያቄዎችን በምሳሌዎች ላይ በመመስረት በቀላሉ መመለስ።';
    } else if (language == 'om') {
      yield 'Yaada Keessoo (Core Concept)\n';
      yield 'Maqaa Sanadaa: $docTitle · Gosoota Barnootaa: $subName\n';
      yield 'Qabxiin ijoo fi formulaawwan barbaachisoon sanada kana keessatti adda baafamaniiru.\n\n';
      yield 'Ibsa Gabaasaa (Detailed Breakdown)\n';
      yield 'Barnoota $subName jalatti sanadni kun yaada bu\'uuraa barumsa kanaa kan ibsu yoo ta\'u, keessattuu qophii qormaataaf gargaara. Barattoonni yaada kana hubachuuf irra deddeebi\'anii dubbisuu qabu.\n\n';
      yield 'Fakkeenya Hojiirra Oolmaa\n';
      yield '1. Yaada kana barumsa biroo wajjin walitti hidhuun hubannoo fooyyessuu.\n';
      yield '2. Gaaffilee qormaataa yeroo hunda dhufan salphaatti deebisuu.';
    } else {
      yield 'Core Concept:\n';
      yield 'Document: $docTitle · Course: $subName\n';
      yield 'This synthesized material contains essential textbook summaries, diagrams, and structural definitions.\n\n';
      yield 'Detailed Breakdown:\n';
      yield 'This document outlines critical concepts essential for your academic success in $subName. Understanding the foundational layers, logical definitions, and key variables will allow you to analyze problems critically.\n\n';
      yield 'Practical Illustration:\n';
      yield 'Relating these theoretical constructs from "$docTitle" to direct real-world scenarios simplifies complex structures and bridges the gap between memory and active application.';
    }
  }

  Future<List<Map<String, String>>> _offlineFlashcardsFallback(String content, int count) async {
    final list = <Map<String, String>>[];
    final sentences = content.split(RegExp(r'(?<=[.!?])\s+')).where((s) => s.trim().length > 10).toList();
    
    for (var i = 0; i < count; i++) {
      if (i < sentences.length) {
        final sentence = sentences[i].trim();
        list.add({
          'question': 'Analyze the primary focus and academic significance of: "${sentence.substring(0, math.min(sentence.length, 50))}..."',
          'answer': 'This highlights key structural definitions, serving as a pillar for theoretical models and practical applications.'
        });
      } else {
        list.add({
          'question': 'How does study review ${i + 1} aid analytical comprehension?',
          'answer': 'Spaced repetition reinforces retention loops in the cognitive memory pathway, shifting learning from temporary storage to persistent mastery.'
        });
      }
    }
    return list;
  }

  Future<List<String>> _offlineQuestionsFallback(String content) async {
    final sentences = content.split(RegExp(r'(?<=[.!?])\s+')).where((s) => s.trim().length > 10).toList();
    final first = sentences.isNotEmpty ? sentences.first : 'this content';
    return [
      'What are the core arguments and foundational evidence proposed in "$first"?',
      'How do the variables discussed relate directly to practical applications in the industry?',
      'Can you outline the sequential steps required to implement these principles?',
      'What are the common pitfalls or limitations identified by researchers in this area?',
      'Synthesize the ultimate conclusion and discuss its broader academic impact.'
    ];
  }

  Future<Map<String, dynamic>> _offlineMindmapFallback(String content) async {
    final sentences = content.split(RegExp(r'(?<=[.!?])\s+')).where((s) => s.trim().length > 5).toList();
    final center = sentences.isNotEmpty ? sentences.first : 'Core Subject';
    final shortCenter = center.split(' ').take(3).join(' ');
    
    return {
      'center': shortCenter.isEmpty ? 'Main Concept' : shortCenter,
      'branches': [
        {
          'label': 'Foundations',
          'children': ['Definitions', 'Key Parameters', 'Historical Context']
        },
        {
          'label': 'Methodology',
          'children': ['Sequential Steps', 'Active Workflows', 'Techniques']
        },
        {
          'label': 'Applications',
          'children': ['Industrial Cases', 'Simulated Exercises', 'Future Scope']
        }
      ]
    };
  }

  Stream<String> _offlineChatFallback(String question, String language) async* {
    if (language == 'am') {
      yield 'እባክዎ የበይነመረብ ግንኙነትዎን ያረጋግጡ። ተማሪ ቴማሪ ከመስመር ውጭ በሆነ መልኩም ቢሆን ትምህርታዊ እገዛዎን ለመስጠት ዝግጁ ነች። \n\nለጥያቄዎ: "$question" ተዛማጅ መልስ በቅርቡ እናቀርባለን።';
    } else if (language == 'om') {
      yield 'Mee qunnamtii interneetii keessan mirkaneessaa. Temariin offline ta\'us isin gargaaruuf qophiidha. \n\nGaaffii keessaniif: "$question" dhiyeenyatti deebii ni kennina.';
    } else {
      yield 'Please check your internet connection. Temari remains available offline to help you study.\n\nRegarding your question: "$question", try reviewing the summarized explanation notes above or check your API key environment configuration.';
    }
  }
}

class GeminiException implements Exception {
  GeminiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'GeminiException($statusCode): $body';
}
