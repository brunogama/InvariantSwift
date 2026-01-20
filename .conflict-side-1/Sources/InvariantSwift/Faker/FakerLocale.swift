// MARK: - ISP-0010: Faker Locale Support
// Locale definitions for realistic data generation.

import Foundation

// MARK: - Faker Locale

/// Supported locales for faker data generation.
public enum FakerLocale: String, Sendable, CaseIterable {
  // Americas
  case enUS = "en_US"
  case enCA = "en_CA"
  case enGB = "en_GB"
  case ptBR = "pt_BR"
  case esMX = "es_MX"
  case esAR = "es_AR"
  case frCA = "fr_CA"

  // Europe
  case deDE = "de_DE"
  case frFR = "fr_FR"
  case itIT = "it_IT"
  case esES = "es_ES"
  case ptPT = "pt_PT"
  case nlNL = "nl_NL"
  case plPL = "pl_PL"
  case ruRU = "ru_RU"
  case ukUA = "uk_UA"

  // Asia
  case jaJP = "ja_JP"
  case koKR = "ko_KR"
  case zhCN = "zh_CN"
  case zhTW = "zh_TW"
  case hiIN = "hi_IN"

  // Other
  case arSA = "ar_SA"
  case heIL = "he_IL"

  /// Language code (e.g., "en", "pt")
  public var languageCode: String {
    String(rawValue.prefix(2))
  }

  /// Country code (e.g., "US", "BR")
  public var countryCode: String {
    String(rawValue.suffix(2))
  }

  /// Display name for the locale
  public var displayName: String {
    switch self {
    case .default, .enUS: return "English (US)"
    case .enCA: return "English (Canada)"
    case .enGB: return "English (UK)"
    case .ptBR: return "Portuguese (Brazil)"
    case .esMX: return "Spanish (Mexico)"
    case .esAR: return "Spanish (Argentina)"
    case .frCA: return "French (Canada)"
    case .deDE: return "German"
    case .frFR: return "French"
    case .itIT: return "Italian"
    case .esES: return "Spanish (Spain)"
    case .ptPT: return "Portuguese (Portugal)"
    case .nlNL: return "Dutch"
    case .plPL: return "Polish"
    case .ruRU: return "Russian"
    case .ukUA: return "Ukrainian"
    case .jaJP: return "Japanese"
    case .koKR: return "Korean"
    case .zhCN: return "Chinese (Simplified)"
    case .zhTW: return "Chinese (Traditional)"
    case .hiIN: return "Hindi"
    case .arSA: return "Arabic"
    case .heIL: return "Hebrew"
    }
  }

  /// Default locale (English US)
  public static var `default`: Self { .enUS }
}
