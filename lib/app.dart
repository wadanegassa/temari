import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_text_styles.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/flashcards/screens/exam_mode_screen.dart';
import 'features/flashcards/screens/flashcards_screen.dart';
import 'features/chat/screens/tutor_chat_screen.dart';
import 'features/home/screens/main_navigation_container.dart';
import 'features/notes/screens/file_note_screen.dart';
import 'features/notes/screens/note_detail_screen.dart';
import 'features/notes/screens/photo_note_screen.dart';
import 'features/notes/screens/voice_note_screen.dart';
import 'features/notes/screens/mindmap_canvas_screen.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/settings/screens/language_pick_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/subjects/screens/create_subject_screen.dart';
import 'features/subjects/screens/subject_detail_screen.dart';
import 'features/subjects/screens/subjects_screen.dart';
import 'features/timer/screens/pomodoro_timer_screen.dart';
import 'shared/screens/pdf_viewer_screen.dart';
import 'shared/screens/chatbot_screen.dart';
import 'shared/screens/quiz_screen.dart';

final _navKey = GlobalKey<NavigatorState>();

ThemeData buildTemariTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bgPrimary,
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      surface: AppColors.bgCard,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgPrimary,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    dividerColor: AppColors.border,
    textTheme: TextTheme(
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.small,
      titleLarge: AppTextStyles.h2,
    ),
  );
}

GoRouter createRouter(WidgetRef ref) {
  return GoRouter(
    navigatorKey: _navKey,
    initialLocation: '/splash',
    refreshListenable: ref.read(authControllerProvider),
    redirect: (context, state) {
      final container = ProviderScope.containerOf(context);
      final auth = container.read(authControllerProvider);
      final settings = container.read(settingsControllerProvider);
      final loc = state.matchedLocation;

      if (!auth.ready && loc != '/splash') return '/splash';
      if (!auth.ready) return null;

      if (loc == '/splash') return null;

      if (!auth.anonymous) {
        if (loc == '/splash' ||
            loc == '/onboarding' ||
            loc == '/language' ||
            loc == '/auth' ||
            loc == '/chatbot') {
          if (!settings.onboardingComplete) {
            settings.setOnboardingComplete(true);
          }
          return '/home';
        }
        return null;
      }

      if (!settings.onboardingComplete) {
        if (loc != '/onboarding' &&
            loc != '/language' &&
            loc != '/splash' &&
            loc != '/auth' &&
            loc != '/chatbot') {
          return '/onboarding';
        }
        return null;
      }

      if (auth.anonymous) {
        if (loc == '/onboarding' ||
            loc == '/language' ||
            loc == '/home' ||
            loc == '/settings') {
          return '/chatbot';
        }
        return null;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/language',
        builder: (_, __) => const LanguagePickScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/chatbot',
        builder: (_, __) => const TutorChatScreen(),
      ),
      GoRoute(
        path: '/chat-session',
        builder: (_, s) => ChatbotScreen(
          subjectId: s.uri.queryParameters['subjectId'],
          noteId: s.uri.queryParameters['noteId'],
        ),
      ),
      GoRoute(
        path: '/quiz-session',
        builder: (_, s) => QuizScreen(
          subjectId: s.uri.queryParameters['subjectId'] ?? '',
          noteId: s.uri.queryParameters['noteId'],
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const MainNavigationContainer(),
      ),
      GoRoute(
        path: '/subjects',
        builder: (_, __) => const SubjectsScreen(),
      ),
      GoRoute(
        path: '/subjects/new',
        builder: (_, __) => const CreateSubjectScreen(),
      ),
      GoRoute(
        path: '/subject/:id',
        builder: (_, s) => SubjectDetailScreen(subjectId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/note/voice',
        builder: (_, s) =>
            VoiceNoteScreen(subjectId: s.uri.queryParameters['subjectId']),
      ),
      GoRoute(
        path: '/note/photo',
        builder: (_, s) => PhotoNoteScreen(
          subjectId: s.uri.queryParameters['subjectId'],
          immediateCapture: s.uri.queryParameters['immediate'] == 'true',
        ),
      ),
      GoRoute(
        path: '/note/pdf',
        builder: (_, s) =>
            FileNoteScreen(subjectId: s.uri.queryParameters['subjectId']),
      ),
      GoRoute(
        path: '/note/text',
        builder: (_, s) =>
            VoiceNoteScreen(subjectId: s.uri.queryParameters['subjectId']),
      ),
      GoRoute(
        path: '/note/:id',
        builder: (_, s) => NoteDetailScreen(noteId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/flashcards/:subjectId',
        builder: (_, s) =>
            FlashcardsScreen(subjectId: s.pathParameters['subjectId']!),
      ),
      GoRoute(
        path: '/exam/:subjectId',
        builder: (_, s) =>
            ExamModeScreen(subjectId: s.pathParameters['subjectId']!),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/timer',
        builder: (_, __) => const PomodoroTimerScreen(),
      ),
      GoRoute(
        path: '/mindmap/:noteId',
        builder: (_, s) => MindMapCanvasScreen(noteId: s.pathParameters['noteId']!),
      ),
      GoRoute(
        path: '/pdf-viewer',
        builder: (_, s) => PdfViewerScreen(
          filePath: s.uri.queryParameters['filePath'] ?? '',
          title: s.uri.queryParameters['title'] ?? 'PDF Document',
        ),
      ),
    ],
  );
}

class TemariApp extends ConsumerStatefulWidget {
  const TemariApp({super.key});

  @override
  ConsumerState<TemariApp> createState() => _TemariAppState();
}

class _TemariAppState extends ConsumerState<TemariApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= createRouter(ref);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: buildTemariTheme(),
      routerConfig: _router!,
    );
  }
}
