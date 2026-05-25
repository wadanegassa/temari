# Temari

Temari is an AI study companion built for Ethiopian students. It combines tutoring, note capture, revision tools, and offline-first storage in one Flutter app so students can keep learning even when the connection is weak or unavailable.

## What Temari Does

Temari is designed to feel like a focused study workspace rather than a generic chat app. It supports:

* AI tutoring for questions, explanations, and study help
* Voice notes and speech-to-text input for fast capture
* Photo, PDF, and text-based note entry
* Flashcards for active revision and recall practice
* A Pomodoro-style focus timer for study sessions
* Offline storage with cloud sync when connectivity is available

## Why It Stands Out

Temari is made for long study sessions and practical use in real environments. The interface leans into warm, readable visuals, while the architecture keeps the app responsive through local caching and background sync.

The result is a tool that can support learners across daily study habits, exam preparation, and quick question-solving without forcing them into a constant online workflow.

## Core Experience

* Chat with an AI study tutor in structured sessions
* Create subject-based notes from text, audio, images, and PDFs
* Turn notes into flashcards for revision
* Predict likely exam questions from study material
* Track study focus with an integrated timer
* Keep data available offline and synced through Supabase when online

## Tech Stack

Temari is built with Flutter and Dart using:

* `flutter_riverpod`, `hooks_riverpod`, and `flutter_hooks` for state management
* `hive` and `hive_flutter` for local offline storage
* `supabase_flutter` for authentication and sync
* `speech_to_text`, `flutter_sound`, and `audio_waveforms` for voice features
* `image_picker`, `file_picker`, `pdfx`, and `open_filex` for study files
* `go_router` and `google_fonts` for navigation and UI polish

## Project Layout

```bash
lib/
├── app.dart
├── main.dart
├── core/
├── features/
└── shared/
```

## Overview

Temari is being shaped as a practical study companion for Ethiopian learners: visually calm, offline-friendly, and centered on real study workflows rather than novelty features.
