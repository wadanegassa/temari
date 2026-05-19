
# Temari

**Temari** is an offline-first AI study companion for Ethiopian students, built with Flutter, Supabase, and Gemini AI.

---

## Features

- **Subjects & Notes:** Organize your study materials by subject. Create notes in text, voice, photo, or PDF formats.
- **Flashcards:** Auto-generate and review flashcards using Gemini AI for exam preparation.
- **Exam Sessions:** Track your study progress and review sessions.
- **AI Summaries:** Get AI-generated summaries and explanations for your notes (Gemini API).
- **Offline-first:** Data is stored locally (Hive) and syncs to Supabase when online.
- **Multi-platform:** Runs on Android, iOS, Linux, macOS, Windows, and Web.

## Project Structure

- `lib/`
	- `app.dart` — Main app widget and routing
	- `main.dart` — Entry point, initializes environment, Hive, Supabase
	- `core/`
		- `config/` — Environment and API key management
		- `constants/` — App-wide constants (colors, strings, styles)
		- `providers/` — Riverpod providers for app state
		- `services/` — Hive, Supabase, Gemini, file, and voice services
		- `utils/` — Helpers (date, language)
	- `features/`
		- `auth/` — Authentication screens and providers
		- `flashcards/` — Flashcard screens and widgets
		- `home/` — Home screen and widgets
		- `notes/` — Note screens (text, voice, photo, file)
		- `settings/` — Settings and language selection
		- `subjects/` — Subject CRUD and detail screens
	- `shared/`
		- `models/` — Data models (Subject, Note, Flashcard, ExamSession)
		- `widgets/` — Common UI widgets

- `assets/` — Static assets and dotenv file
- `supabase/`
	- `migrations/` — Database migration SQL files
	- `functions/` — (Optional) Supabase Edge Functions
	- `reference_schema.sql` — Reference schema for all tables

## Database Schema (Supabase)

See `supabase/reference_schema.sql` and `supabase/migrations/` for the full schema. Main tables:

- `profiles` — User profile, linked to Supabase Auth
- `subjects` — Study subjects
- `notes` — Notes (text, voice, photo, file)
- `flashcards` — Flashcards for spaced repetition
- `exam_sessions` — Tracks exam review sessions

## Environment Setup

1. **Clone the repo:**
	 ```sh
	 git clone <repo-url>
	 cd temari
	 ```
2. **Install dependencies:**
	 ```sh
	 flutter pub get
	 ```
3. **Configure environment:**
	 - Copy `.env.example` to `.env` and fill in your keys:
		 - `GEMINI_API_KEY` (Google Gemini API)
		 - `SUPABASE_URL` and `SUPABASE_ANON_KEY`
4. **Run the app:**
	 ```sh
	 flutter run
	 ```
5. **Supabase CLI (for migrations):**
	 ```sh
	 npx supabase login
	 npx supabase link
	 npx supabase db push
	 ```

## AI Integration

- Uses [Gemini 3.1 Flash Lite](https://ai.google.dev/gemini-api/docs/pricing#gemini-3.1-flash-lite) for flashcard generation and note summarization.
- Configure your API key in `.env` or `assets/dotenv`.

## Local & Cloud Sync

- Data is stored locally with Hive for offline access.
- Supabase is used for authentication and cloud sync (when configured).

## Testing

- Run widget tests:
	```sh
	flutter test
	```

## Contributing

Pull requests are welcome! Please open issues for suggestions or bugs.

---

**Temari** © 2026
