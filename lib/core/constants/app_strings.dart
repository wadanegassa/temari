import '../utils/language_helper.dart';

/// Central UI copy in English, Amharic, and Afaan Oromo.
class AppStrings {
  AppStrings._();

  static const Map<String, Map<AppLanguageCode, String>> _strings = {
    'app_name': {
      kLangEnglish: 'Temari',
      kLangAmharic: 'ተማሪ',
      kLangOromo: 'Temari',
    },
    'home_greeting': {
      kLangEnglish: 'Good morning',
      kLangAmharic: 'እንደምን አደሩ',
      kLangOromo: 'Akkam bultan',
    },
    'home_greeting_afternoon': {
      kLangEnglish: 'Good afternoon',
      kLangAmharic: 'እንደምን ዋልክ',
      kLangOromo: 'Akkam ooltan',
    },
    'home_greeting_evening': {
      kLangEnglish: 'Good evening',
      kLangAmharic: 'መልካም ምሽት',
      kLangOromo: 'Galatoomi',
    },
    'quick_add_voice': {
      kLangEnglish: 'Voice note',
      kLangAmharic: 'የድምፅ ማስታወሻ',
      kLangOromo: 'Yaada sagalee',
    },
    'quick_add_photo': {
      kLangEnglish: 'Snap photo',
      kLangAmharic: 'ፎቶ አንሳ',
      kLangOromo: 'Suuraa kaadi',
    },
    'quick_add_file': {
      kLangEnglish: 'Upload PDF',
      kLangAmharic: 'PDF ጫን',
      kLangOromo: 'PDF fe\'i',
    },
    'quick_add_text': {
      kLangEnglish: 'Write note',
      kLangAmharic: 'ማስታወሻ ጻፍ',
      kLangOromo: 'Barreessi',
    },
    'your_subjects': {
      kLangEnglish: 'Your subjects',
      kLangAmharic: 'የእርስዎ ትምህርቶች',
      kLangOromo: 'Barnoota keessan',
    },
    'add_subject': {
      kLangEnglish: 'Add',
      kLangAmharic: 'ጨምር',
      kLangOromo: 'Dabali',
    },
    'recent_notes': {
      kLangEnglish: 'Recently studied',
      kLangAmharic: 'በቅርብ የተማሩ',
      kLangOromo: 'Dhiyoo baratan',
    },
    'generate_flashcards': {
      kLangEnglish: 'Generate flashcards',
      kLangAmharic: 'ፍላሽካርዶችን ፍጠር',
      kLangOromo: 'Kaardoota uumi',
    },
    'exam_mode': {
      kLangEnglish: 'Start exam mode',
      kLangAmharic: 'ፈተናን ጀምር',
      kLangOromo: 'Qorumsa jalqabi',
    },
    'settings': {
      kLangEnglish: 'Settings',
      kLangAmharic: 'ቅንብሮች',
      kLangOromo: 'Qindaa\'ina',
    },
    'continue_without': {
      kLangEnglish: 'Use without account →',
      kLangAmharic: 'ያለመለያ ተጠቀም →',
      kLangOromo: 'Akkaawuntii malee fayyadami →',
    },
    'sign_in': {
      kLangEnglish: 'Sign in',
      kLangAmharic: 'ግባ',
      kLangOromo: 'Seeni',
    },
    'sign_up': {
      kLangEnglish: 'Sign up',
      kLangAmharic: 'ተመዝገብ',
      kLangOromo: 'Galmaa\'i',
    },
    'email': {
      kLangEnglish: 'Email',
      kLangAmharic: 'ኢሜይል',
      kLangOromo: 'Imeelii',
    },
    'password': {
      kLangEnglish: 'Password',
      kLangAmharic: 'የይለፍ ቃል',
      kLangOromo: 'Jeecha icciitii',
    },
    'save': {
      kLangEnglish: 'Save',
      kLangAmharic: 'አስቀምጥ',
      kLangOromo: 'Ol kaa\'i',
    },
    'cancel': {
      kLangEnglish: 'Cancel',
      kLangAmharic: 'ሰርዝ',
      kLangOromo: 'Adda kuti',
    },
    'explain_ai': {
      kLangEnglish: 'Explain with AI',
      kLangAmharic: 'በAI አብራራ',
      kLangOromo: 'AI\'n ibsi',
    },
    'process_ai': {
      kLangEnglish: 'Process with AI',
      kLangAmharic: 'በAI አስኬድ',
      kLangOromo: 'AI\'n hojjechi',
    },
    'offline_ai_pending': {
      kLangEnglish:
          'You are offline. AI will run when you are back online.',
      kLangAmharic: 'ከመስመር ውጭ ነዎት። AI ሲመለስ ይሰራል።',
      kLangOromo: 'Ala sararaa jirtu. Yeroo deebitee AI hojjata.',
    },
    'onboarding_1_title': {
      kLangEnglish: 'Your study companion',
      kLangAmharic: 'የእርስዎ የትምህርት ጓደኛ',
      kLangOromo: 'Gargaara barnoota keessan',
    },
    'onboarding_1_body': {
      kLangEnglish:
          'Capture voice, photos, PDFs, and notes — then learn with depth.',
      kLangAmharic: 'ድምፅ፣ ፎቶ፣ PDF እና ማስታወሻ ይያዙ — ከዚያ በጥልቀት ይማሩ።',
      kLangOromo: 'Sagalee, suuraa, PDF fi yaada qabattan — booddee baradhaa.',
    },
    'onboarding_2_title': {
      kLangEnglish: 'In your language',
      kLangAmharic: 'በእርስዎ ቋንቋ',
      kLangOromo: 'Afaan keessan keessatti',
    },
    'onboarding_2_body': {
      kLangEnglish: 'Amharic, Afaan Oromo, or English — always your choice.',
      kLangAmharic: 'አማርኛ፣ አፋን ኦሮሞ ወይም እንግሊዝኛ።',
      kLangOromo: 'Afaan Oromoo, Amaaraa ykn Ingiliffaa.',
    },
    'onboarding_3_title': {
      kLangEnglish: 'Offline, always ready',
      kLangAmharic: 'ከመስመር ውጭ፣ ሁልጊዜ ዝግጁ',
      kLangOromo: 'Ala sararaa, yeroo hunda diyaara',
    },
    'onboarding_3_body': {
      kLangEnglish: 'Your notes stay on your phone first, then sync when you sign in.',
      kLangAmharic: 'ማስታወሻዎ በስልክዎ ይቆያል፣ ከዚያ ይመሳሰላል።',
      kLangOromo: 'Yaanni keessan bilbilaa keessatti jiraata, booda walitti maku.',
    },
    'next': {
      kLangEnglish: 'Next',
      kLangAmharic: 'ቀጣይ',
      kLangOromo: 'Itti aanu',
    },
    'skip': {
      kLangEnglish: 'Skip',
      kLangAmharic: 'ዝለል',
      kLangOromo: 'Darbi',
    },
    'get_started': {
      kLangEnglish: 'Get started',
      kLangAmharic: 'ጀምር',
      kLangOromo: 'Jalqabi',
    },
    'language_pick_title': {
      kLangEnglish: 'Choose your language',
      kLangAmharic: 'ቋንቋዎን ይምረጡ',
      kLangOromo: 'Afaan filadhu',
    },
    'notes_tab': {
      kLangEnglish: 'Notes',
      kLangAmharic: 'ማስታወሻዎች',
      kLangOromo: 'Yaadannoo',
    },
    'flashcards_tab': {
      kLangEnglish: 'Flashcards',
      kLangAmharic: 'ፍላሽካርዶች',
      kLangOromo: 'Kaardoota',
    },
    'original_content': {
      kLangEnglish: 'Original content',
      kLangAmharic: 'ዋና ይዘት',
      kLangOromo: 'Qabiyyee bu\'uuraa',
    },
    'ai_explanation': {
      kLangEnglish: 'AI explanation',
      kLangAmharic: 'የAI ማብራሪያ',
      kLangOromo: 'Ibsa AI',
    },
    'predicted_exam': {
      kLangEnglish: 'Predicted exam questions',
      kLangAmharic: 'የሚጠበቁ የፈተና ጥያቄዎች',
      kLangOromo: 'Gaaffilee qoromaa eegaman',
    },
    'regenerate': {
      kLangEnglish: 'Regenerate',
      kLangAmharic: 'እንደገና ፍጠር',
      kLangOromo: 'Ammas uumi',
    },
    'view_all_cards': {
      kLangEnglish: 'View all',
      kLangAmharic: 'ሁሉንም',
      kLangOromo: 'Hunda ilaali',
    },
    'exam_begin': {
      kLangEnglish: 'Begin',
      kLangAmharic: 'ጀምር',
      kLangOromo: 'Jalqabi',
    },
    'exam_show_answer': {
      kLangEnglish: 'Show answer',
      kLangAmharic: 'መልስ አሳይ',
      kLangOromo: 'Deebii agarsiisi',
    },
    'exam_got_it': {
      kLangEnglish: 'Got it',
      kLangAmharic: 'ተረድቻለሁ',
      kLangOromo: 'Argadheera',
    },
    'exam_almost': {
      kLangEnglish: 'Almost',
      kLangAmharic: 'በከፊል',
      kLangOromo: 'Xiqqaa',
    },
    'exam_missed': {
      kLangEnglish: 'Missed',
      kLangAmharic: 'አልተረዳሁም',
      kLangOromo: 'Hin arganne',
    },
    'exam_done': {
      kLangEnglish: 'Done',
      kLangAmharic: 'ተጠናቀቀ',
      kLangOromo: 'Xumurameera',
    },
    'study_weak': {
      kLangEnglish: 'Study weak cards again',
      kLangAmharic: 'ደካሞችን እንደገና',
      kLangOromo: 'Kaardota dadhaboo ammas baradhaa',
    },
    'account': {
      kLangEnglish: 'Account',
      kLangAmharic: 'መለያ',
      kLangOromo: 'Akkaawuntii',
    },
    'study_preferences': {
      kLangEnglish: 'Study preferences',
      kLangAmharic: 'የትምህርት ምርጫዎች',
      kLangOromo: 'Filannoo barnootaa',
    },
    'data': {
      kLangEnglish: 'Data',
      kLangAmharic: 'ዳታ',
      kLangOromo: 'Daataa',
    },
    'about': {
      kLangEnglish: 'About',
      kLangAmharic: 'ስለ',
      kLangOromo: 'Waa\'ee',
    },
    'sync_status': {
      kLangEnglish: 'Sync status',
      kLangAmharic: 'የማመሳሰል ሁኔታ',
      kLangOromo: 'Haala walitti makuu',
    },
    'export_data': {
      kLangEnglish: 'Export my data',
      kLangAmharic: 'ዳታ ላክ',
      kLangOromo: 'Daataa baasii',
    },
    'delete_local': {
      kLangEnglish: 'Delete all local data',
      kLangAmharic: 'ሁሉንም አጥፋ',
      kLangOromo: 'Daataa naannoo hunda haqi',
    },
    'sign_out': {
      kLangEnglish: 'Sign out',
      kLangAmharic: 'ውጣ',
      kLangOromo: 'Ba\'i',
    },
    'create_account_sync': {
      kLangEnglish:
          'Create a free account to back up your notes on any device.',
      kLangAmharic: 'መለያ ይፍጠሩ እና ዳታዎ ይጠበቃል።',
      kLangOromo: 'Akkaawuntii bilisaa uumaa fi daataa keessan eegaa.',
    },
    'built_for': {
      kLangEnglish: 'Built for Ethiopian students',
      kLangAmharic: 'ለኢትዮጵያ ተማሪዎች የተሰራ',
      kLangOromo: 'Barattoota Itoophiyaaaf kan ijaarame',
    },
    'streak': {
      kLangEnglish: 'Day streak',
      kLangAmharic: 'ቀናት ተከታታይ',
      kLangOromo: 'Guyyaa walitti hidhamuu',
    },
    'subject_name': {
      kLangEnglish: 'Subject name',
      kLangAmharic: 'የትምህርት ስም',
      kLangOromo: 'Maqaa barnootaa',
    },
    'create_subject': {
      kLangEnglish: 'New subject',
      kLangAmharic: 'አዲስ ትምህርት',
      kLangOromo: 'Barnoota haaraa',
    },
    'note_title': {
      kLangEnglish: 'Title',
      kLangAmharic: 'ርዕስ',
      kLangOromo: 'Mata duree',
    },
    'empty_subjects': {
      kLangEnglish: 'Add a subject to start organizing notes.',
      kLangAmharic: 'ትምህርት ይጨምሩ።',
      kLangOromo: 'Barnoota dabaluun yaadannoo qindeessi.',
    },
    'empty_notes': {
      kLangEnglish: 'No notes yet.',
      kLangAmharic: 'እስካሁን ማስታወሻ የለም።',
      kLangOromo: 'Amma ammatti yaadannoon hin jiru.',
    },
    'limit_reached': {
      kLangEnglish: 'Free limit reached. Unlock Temari Pro for more.',
      kLangAmharic: 'የነፃ ገደብ ተሞልቷል።',
      kLangOromo: 'Daangaa bilisaa ga\'e. Pro fayyadami.',
    },
    'pdf_locked': {
      kLangEnglish: 'PDF upload is part of Temari Pro.',
      kLangAmharic: 'PDF በPro ውስጥ ነው።',
      kLangOromo: 'PDF Pro keessatti argama.',
    },
    'retry': {
      kLangEnglish: 'Retry',
      kLangAmharic: 'እንደገና ሞክር',
      kLangOromo: 'Ammas yaali',
    },
    'unlock_pro': {
      kLangEnglish: 'Unlock Temari Pro',
      kLangAmharic: 'Pro ክፈት',
      kLangOromo: 'Pro bani',
    },
    'display_name': {
      kLangEnglish: 'Display name',
      kLangAmharic: 'ስም',
      kLangOromo: 'Maqaa',
    },
    'daily_reminder': {
      kLangEnglish: 'Daily study reminder',
      kLangAmharic: 'ዕለታዊ አስታዋሽ',
      kLangOromo: 'Yaadannoo guyyaawaa',
    },
    'auto_flashcards': {
      kLangEnglish: 'Auto-generate flashcards',
      kLangAmharic: 'ፍላሽካርድ አውቶማቲክ',
      kLangOromo: 'Kaardoota ofumaan',
    },
    'tap_reveal': {
      kLangEnglish: 'Tap to reveal answer',
      kLangAmharic: 'ለመመልስ ነካ ያድርጉ',
      kLangOromo: 'Deebii agarsiisuf tuqi',
    },
    'question': {
      kLangEnglish: 'Question',
      kLangAmharic: 'ጥያቄ',
      kLangOromo: 'Gaaffii',
    },
    'answer': {
      kLangEnglish: 'Answer',
      kLangAmharic: 'መልስ',
      kLangOromo: 'Deebii',
    },
    'type_voice': {
      kLangEnglish: 'Voice',
      kLangAmharic: 'ድምፅ',
      kLangOromo: 'Sagalee',
    },
    'type_photo': {
      kLangEnglish: 'Photo',
      kLangAmharic: 'ፎቶ',
      kLangOromo: 'Suuraa',
    },
    'type_file': {
      kLangEnglish: 'PDF',
      kLangAmharic: 'PDF',
      kLangOromo: 'PDF',
    },
    'type_text': {
      kLangEnglish: 'Text',
      kLangAmharic: 'ጽሑፍ',
      kLangOromo: 'Barreeffama',
    },
    'last_synced': {
      kLangEnglish: 'Last synced',
      kLangAmharic: 'የመጨረሻ ማመሳሰል',
      kLangOromo: 'Yeroo dhuma walitti makame',
    },
    'never': {
      kLangEnglish: 'Never',
      kLangAmharic: 'ፈጽሞ',
      kLangOromo: 'Homaa',
    },
    'pro_feature_predictions': {
      kLangEnglish: 'Exam predictions are part of Temari Pro.',
      kLangAmharic: 'የፈተና ትንቢት በPro ውስጥ ነው።',
      kLangOromo: 'Eegumsa qoromaa Pro keessatti.',
    },
  };

  static String get(String key, String lang) {
    final row = _strings[key];
    if (row == null) return key;
    return row[lang] ?? row[kLangEnglish] ?? key;
  }
}
