/// BCP-style language codes used across the app.
typedef AppLanguageCode = String;

const kLangEnglish = 'en';
const kLangAmharic = 'am';
const kLangOromo = 'om';

String languageDisplayName(String code) {
  switch (code) {
    case kLangAmharic:
      return 'አማርኛ';
    case kLangOromo:
      return 'Afaan Oromo';
    default:
      return 'English';
  }
}

bool isRtlLanguage(String code) => code == kLangAmharic;
