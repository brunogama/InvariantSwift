// MARK: - ISP-0010: Faker Data
// Locale-specific data for fake data generation.

import Foundation

// MARK: - Faker Data

/// Thread-safe lazy-loaded faker data storage.
// swiftlint:disable file_length function_body_length type_body_length
public final class FakerData: @unchecked Sendable {
  public static let shared = FakerData()

  private var loadedLocales: [FakerLocale: LocaleData] = [:]
  private let lock = NSLock()

  private init() {}

  /// Get locale data, loading lazily if needed.
  public func data(for locale: FakerLocale) -> LocaleData {
    lock.lock()
    defer { lock.unlock() }

    // Resolve default
    let resolvedLocale = locale == .default ? .enUS : locale

    if let cached = loadedLocales[resolvedLocale] {
      return cached
    }

    let data = LocaleData.create(for: resolvedLocale)
    loadedLocales[resolvedLocale] = data
    return data
  }
}

// MARK: - Locale Data

/// Data for a specific locale.
public struct LocaleData: Sendable {
  public let locale: FakerLocale

  // Names
  public let firstNames: [String]
  public let lastNames: [String]
  public let prefixes: [String]
  public let suffixes: [String]

  // Internet
  public let emailDomains: [String]
  public let domainSuffixes: [String]

  // Address
  public let cities: [String]
  public let states: [String]
  public let countries: [String]
  public let streetSuffixes: [String]
  public let phoneFormats: [String]

  // Company
  public let companyNames: [String]
  public let companySuffixes: [String]
  public let industries: [String]
  public let jobTitles: [String]
  public let departments: [String]
  public let buzzwords: [String]
  public let catchPhrases: [String]

  // Lorem
  public let loremWords: [String]

  // Create locale data
  public static func create(for locale: FakerLocale) -> Self {
    switch locale {
    case .ptBR:
      return createBrazilianPortuguese()

    case .deDE:
      return createGerman()

    case .frFR:
      return createFrench()

    case .esES, .esMX, .esAR:
      return createSpanish()

    case .jaJP:
      return createJapanese()

    default:
      return createEnglishUS()
    }
  }

  // MARK: - English (US) Data

  private static func createEnglishUS() -> Self {
    Self(
      locale: .enUS,
      firstNames: [
        "James", "Mary", "John", "Patricia", "Robert", "Jennifer",
        "Michael", "Linda", "William", "Elizabeth", "David", "Barbara",
        "Richard", "Susan", "Joseph", "Jessica", "Thomas", "Sarah",
        "Charles", "Karen", "Christopher", "Nancy", "Daniel", "Lisa",
        "Matthew", "Betty", "Anthony", "Margaret", "Mark", "Sandra",
        "Donald", "Ashley", "Steven", "Kimberly", "Paul", "Emily",
        "Andrew", "Donna", "Joshua", "Michelle", "Kenneth", "Dorothy",
        "Kevin", "Carol", "Brian", "Amanda", "George", "Melissa",
        "Edward", "Deborah", "Ronald", "Stephanie", "Timothy", "Rebecca",
        "Jason", "Sharon", "Jeffrey", "Laura", "Ryan", "Cynthia",
      ],
      lastNames: [
        "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia",
        "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez",
        "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore",
        "Jackson", "Martin", "Lee", "Perez", "Thompson", "White",
        "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson",
        "Walker", "Young", "Allen", "King", "Wright", "Scott",
        "Torres", "Nguyen", "Hill", "Flores", "Green", "Adams",
        "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell",
        "Carter", "Roberts", "Gomez", "Phillips", "Evans", "Turner",
        "Diaz", "Parker", "Cruz", "Edwards", "Collins", "Reyes",
      ],
      prefixes: ["Mr.", "Mrs.", "Ms.", "Dr.", "Prof."],
      suffixes: ["Jr.", "Sr.", "II", "III", "IV", "PhD", "MD", "Esq."],
      emailDomains: [
        "gmail.com", "yahoo.com", "hotmail.com", "outlook.com",
        "icloud.com", "me.com", "mail.com", "protonmail.com",
      ],
      domainSuffixes: [".com", ".org", ".net", ".io", ".co", ".us", ".edu"],
      cities: [
        "New York", "Los Angeles", "Chicago", "Houston", "Phoenix",
        "Philadelphia", "San Antonio", "San Diego", "Dallas", "San Jose",
        "Austin", "Jacksonville", "Fort Worth", "Columbus", "Charlotte",
        "San Francisco", "Indianapolis", "Seattle", "Denver", "Boston",
        "Portland", "Las Vegas", "Detroit", "Memphis", "Nashville",
      ],
      states: [
        "Alabama", "Alaska", "Arizona", "Arkansas", "California",
        "Colorado", "Connecticut", "Delaware", "Florida", "Georgia",
        "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas",
        "Kentucky", "Louisiana", "Maine", "Maryland", "Massachusetts",
        "Michigan", "Minnesota", "Mississippi", "Missouri", "Montana",
        "Nebraska", "Nevada", "New Hampshire", "New Jersey", "New Mexico",
        "New York", "North Carolina", "North Dakota", "Ohio", "Oklahoma",
        "Oregon", "Pennsylvania", "Rhode Island", "South Carolina",
        "South Dakota", "Tennessee", "Texas", "Utah", "Vermont",
        "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming",
      ],
      countries: [
        "United States", "Canada", "Mexico", "United Kingdom", "Germany",
        "France", "Italy", "Spain", "Australia", "Japan", "Brazil",
        "India", "China", "South Korea", "Netherlands", "Sweden",
      ],
      streetSuffixes: [
        "Street", "Avenue", "Boulevard", "Drive", "Lane",
        "Road", "Circle", "Court", "Place", "Way",
      ],
      phoneFormats: ["(###) ###-####", "###-###-####", "+1 ### ### ####"],
      companyNames: [
        "Acme", "Globex", "Initech", "Umbrella", "Wayne", "Stark",
        "Hooli", "Pied Piper", "Cyberdyne", "Weyland", "Tyrell",
      ],
      companySuffixes: [
        "Inc.", "Corp.", "LLC", "Ltd.", "Group", "Holdings",
        "Industries", "Technologies", "Solutions", "Systems",
      ],
      industries: [
        "Technology", "Healthcare", "Finance", "Education", "Retail",
        "Manufacturing", "Real Estate", "Transportation", "Energy",
        "Entertainment", "Hospitality", "Agriculture", "Construction",
      ],
      jobTitles: [
        "Software Engineer", "Product Manager", "Designer", "Analyst",
        "Director", "Manager", "Coordinator", "Specialist", "Consultant",
        "Developer", "Architect", "Lead", "Vice President", "CEO", "CTO",
      ],
      departments: [
        "Engineering", "Product", "Design", "Marketing", "Sales",
        "Finance", "Human Resources", "Operations", "Legal", "Support",
      ],
      buzzwords: [
        "synergy", "leverage", "paradigm", "scalable", "robust",
        "innovative", "disruptive", "agile", "cloud-native", "AI-powered",
      ],
      catchPhrases: [
        "Innovate your future", "Drive success forward",
        "Transform possibilities", "Build better together",
      ],
      loremWords: [
        "lorem", "ipsum", "dolor", "sit", "amet", "consectetur",
        "adipiscing", "elit", "sed", "do", "eiusmod", "tempor",
        "incididunt", "ut", "labore", "et", "dolore", "magna", "aliqua",
        "enim", "ad", "minim", "veniam", "quis", "nostrud", "exercitation",
        "ullamco", "laboris", "nisi", "aliquip", "ex", "ea", "commodo",
        "consequat", "duis", "aute", "irure", "in", "reprehenderit",
        "voluptate", "velit", "esse", "cillum", "fugiat", "nulla", "pariatur",
      ]
    )
  }

  // MARK: - Portuguese (Brazil) Data

  private static func createBrazilianPortuguese() -> Self {
    Self(
      locale: .ptBR,
      firstNames: [
        "João", "Maria", "José", "Ana", "Pedro", "Francisca", "Carlos",
        "Antônia", "Paulo", "Adriana", "Lucas", "Juliana", "Marcos",
        "Mariana", "Luiz", "Fernanda", "Gabriel", "Patricia", "Rafael",
        "Aline", "Daniel", "Camila", "Rodrigo", "Amanda", "Bruno",
        "Larissa", "Gustavo", "Beatriz", "Felipe", "Leticia", "Thiago",
        "Bruna", "Matheus", "Carolina", "Leonardo", "Gabriela", "Diego",
        "Bianca", "Marcelo", "Natália", "Vinícius", "Vanessa", "Eduardo",
      ],
      lastNames: [
        "Silva", "Santos", "Oliveira", "Souza", "Rodrigues", "Ferreira",
        "Alves", "Pereira", "Lima", "Gomes", "Costa", "Ribeiro",
        "Martins", "Carvalho", "Almeida", "Lopes", "Soares", "Fernandes",
        "Vieira", "Barbosa", "Rocha", "Dias", "Nascimento", "Andrade",
        "Moreira", "Nunes", "Marques", "Machado", "Mendes", "Freitas",
        "Cardoso", "Ramos", "Gonçalves", "Santana", "Teixeira", "Correia",
      ],
      prefixes: ["Sr.", "Sra.", "Dr.", "Dra.", "Prof.", "Profa."],
      suffixes: ["Filho", "Neto", "Júnior", "Sobrinho"],
      emailDomains: [
        "gmail.com", "hotmail.com", "outlook.com", "yahoo.com.br",
        "uol.com.br", "bol.com.br", "terra.com.br", "ig.com.br",
      ],
      domainSuffixes: [".com.br", ".org.br", ".net.br", ".edu.br", ".gov.br"],
      cities: [
        "São Paulo", "Rio de Janeiro", "Brasília", "Salvador", "Fortaleza",
        "Belo Horizonte", "Manaus", "Curitiba", "Recife", "Porto Alegre",
        "Belém", "Goiânia", "Guarulhos", "Campinas", "São Luís",
        "São Gonçalo", "Maceió", "Duque de Caxias", "Natal", "Teresina",
      ],
      states: [
        "Acre", "Alagoas", "Amapá", "Amazonas", "Bahia", "Ceará",
        "Distrito Federal", "Espírito Santo", "Goiás", "Maranhão",
        "Mato Grosso", "Mato Grosso do Sul", "Minas Gerais", "Pará",
        "Paraíba", "Paraná", "Pernambuco", "Piauí", "Rio de Janeiro",
        "Rio Grande do Norte", "Rio Grande do Sul", "Rondônia", "Roraima",
        "Santa Catarina", "São Paulo", "Sergipe", "Tocantins",
      ],
      countries: [
        "Brasil", "Argentina", "Chile", "Uruguai", "Paraguai", "Colômbia",
        "Peru", "Venezuela", "Bolívia", "Equador", "Portugal", "Espanha",
      ],
      streetSuffixes: [
        "Rua", "Avenida", "Alameda", "Travessa", "Praça",
        "Estrada", "Rodovia", "Largo", "Viela",
      ],
      phoneFormats: ["(##) ####-####", "(##) #####-####", "+55 ## #####-####"],
      companyNames: [
        "Petrobras", "Vale", "Itaú", "Bradesco", "Ambev", "JBS",
        "Natura", "Magazine Luiza", "Nubank", "iFood", "PagSeguro",
      ],
      companySuffixes: [
        "S.A.", "Ltda.", "ME", "EPP", "EIRELI", "S/S",
      ],
      industries: [
        "Tecnologia", "Saúde", "Finanças", "Educação", "Varejo",
        "Indústria", "Imobiliário", "Transporte", "Energia", "Agronegócio",
      ],
      jobTitles: [
        "Desenvolvedor", "Gerente", "Analista", "Diretor", "Coordenador",
        "Consultor", "Especialista", "Supervisor", "Assistente", "Estagiário",
      ],
      departments: [
        "Engenharia", "Produto", "Design", "Marketing", "Vendas",
        "Financeiro", "Recursos Humanos", "Operações", "Jurídico", "Suporte",
      ],
      buzzwords: [
        "inovação", "transformação digital", "escalável", "disruptivo",
        "inteligência artificial", "machine learning", "cloud", "ágil",
      ],
      catchPhrases: [
        "Inovando o futuro", "Conectando pessoas", "Transformando vidas",
      ],
      loremWords: [
        "lorem", "ipsum", "dolor", "sit", "amet", "consectetur",
        "adipiscing", "elit", "sed", "do", "eiusmod", "tempor",
      ]
    )
  }

  // MARK: - German Data

  private static func createGerman() -> Self {
    Self(
      locale: .deDE,
      firstNames: [
        "Hans", "Anna", "Peter", "Maria", "Michael", "Julia", "Thomas",
        "Sandra", "Andreas", "Claudia", "Stefan", "Nicole", "Markus",
        "Sabine", "Christian", "Karin", "Martin", "Petra", "Frank",
        "Monika", "Daniel", "Susanne", "Matthias", "Birgit", "Sebastian",
      ],
      lastNames: [
        "Müller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer",
        "Wagner", "Becker", "Schulz", "Hoffmann", "Schäfer", "Koch",
        "Bauer", "Richter", "Klein", "Wolf", "Schröder", "Neumann",
        "Schwarz", "Zimmermann", "Braun", "Krüger", "Hofmann", "Hartmann",
      ],
      prefixes: ["Herr", "Frau", "Dr.", "Prof.", "Prof. Dr."],
      suffixes: ["junior", "senior"],
      emailDomains: [
        "gmail.com", "web.de", "gmx.de", "t-online.de", "outlook.de",
      ],
      domainSuffixes: [".de", ".at", ".ch", ".com", ".eu"],
      cities: [
        "Berlin", "Hamburg", "München", "Köln", "Frankfurt", "Stuttgart",
        "Düsseldorf", "Dortmund", "Essen", "Leipzig", "Bremen", "Dresden",
      ],
      states: [
        "Baden-Württemberg", "Bayern", "Berlin", "Brandenburg", "Bremen",
        "Hamburg", "Hessen", "Mecklenburg-Vorpommern", "Niedersachsen",
        "Nordrhein-Westfalen", "Rheinland-Pfalz", "Saarland", "Sachsen",
        "Sachsen-Anhalt", "Schleswig-Holstein", "Thüringen",
      ],
      countries: [
        "Deutschland", "Österreich", "Schweiz", "Frankreich", "Italien",
      ],
      streetSuffixes: [
        "Straße", "Weg", "Platz", "Allee", "Ring", "Gasse",
      ],
      phoneFormats: ["+49 ### #######", "0### #######"],
      companyNames: [
        "Volkswagen", "Siemens", "BMW", "Daimler", "SAP", "Deutsche Bank",
      ],
      companySuffixes: ["GmbH", "AG", "KG", "e.V.", "OHG"],
      industries: [
        "Technologie", "Gesundheit", "Finanzen", "Bildung", "Handel",
      ],
      jobTitles: [
        "Entwickler", "Manager", "Analyst", "Direktor", "Berater",
      ],
      departments: [
        "Entwicklung", "Produkt", "Design", "Marketing", "Vertrieb", "Finanzen",
      ],
      buzzwords: ["Innovation", "Digitalisierung", "Nachhaltigkeit"],
      catchPhrases: ["Qualität aus Deutschland"],
      loremWords: [
        "lorem", "ipsum", "dolor", "sit", "amet", "consectetur",
      ]
    )
  }

  // MARK: - French Data

  private static func createFrench() -> Self {
    Self(
      locale: .frFR,
      firstNames: [
        "Jean", "Marie", "Pierre", "Françoise", "Michel", "Monique",
        "André", "Jacqueline", "Philippe", "Isabelle", "Alain", "Nathalie",
        "Bernard", "Sylvie", "Jacques", "Catherine", "Daniel", "Christine",
      ],
      lastNames: [
        "Martin", "Bernard", "Dubois", "Thomas", "Robert", "Richard",
        "Petit", "Durand", "Leroy", "Moreau", "Simon", "Laurent",
        "Lefebvre", "Michel", "Garcia", "David", "Bertrand", "Roux",
      ],
      prefixes: ["M.", "Mme", "Mlle", "Dr", "Pr"],
      suffixes: ["fils", "père"],
      emailDomains: [
        "gmail.com", "orange.fr", "free.fr", "sfr.fr", "laposte.net",
      ],
      domainSuffixes: [".fr", ".com", ".eu", ".org"],
      cities: [
        "Paris", "Marseille", "Lyon", "Toulouse", "Nice", "Nantes",
        "Strasbourg", "Montpellier", "Bordeaux", "Lille", "Rennes",
      ],
      states: [
        "Île-de-France", "Provence-Alpes-Côte d'Azur", "Occitanie",
        "Nouvelle-Aquitaine", "Auvergne-Rhône-Alpes", "Bretagne",
      ],
      countries: [
        "France", "Belgique", "Suisse", "Canada", "Luxembourg",
      ],
      streetSuffixes: [
        "Rue", "Avenue", "Boulevard", "Place", "Chemin", "Allée",
      ],
      phoneFormats: ["+33 # ## ## ## ##", "0# ## ## ## ##"],
      companyNames: [
        "Total", "L'Oréal", "LVMH", "Carrefour", "Renault", "Airbus",
      ],
      companySuffixes: ["SA", "SARL", "SAS", "EURL"],
      industries: [
        "Technologie", "Santé", "Finance", "Éducation", "Commerce",
      ],
      jobTitles: [
        "Développeur", "Directeur", "Analyste", "Consultant", "Ingénieur",
      ],
      departments: [
        "Ingénierie", "Produit", "Design", "Marketing", "Ventes", "Finance",
      ],
      buzzwords: ["innovation", "transformation digitale", "agilité"],
      catchPhrases: ["L'excellence à la française"],
      loremWords: [
        "lorem", "ipsum", "dolor", "sit", "amet", "consectetur",
      ]
    )
  }

  // MARK: - Spanish Data

  private static func createSpanish() -> Self {
    Self(
      locale: .esES,
      firstNames: [
        "Antonio", "María", "José", "Carmen", "Manuel", "Ana", "Francisco",
        "Isabel", "David", "Laura", "Juan", "Marta", "Carlos", "Cristina",
        "Jesús", "Elena", "Miguel", "Lucía", "Ángel", "Paula", "Pedro",
      ],
      lastNames: [
        "García", "Rodríguez", "Martínez", "López", "González", "Hernández",
        "Pérez", "Sánchez", "Ramírez", "Torres", "Flores", "Rivera",
        "Gómez", "Díaz", "Reyes", "Cruz", "Morales", "Ortiz", "Jiménez",
      ],
      prefixes: ["Sr.", "Sra.", "Srta.", "Dr.", "Dra."],
      suffixes: ["hijo", "júnior"],
      emailDomains: [
        "gmail.com", "hotmail.com", "yahoo.es", "outlook.es", "telefonica.net",
      ],
      domainSuffixes: [".es", ".com", ".org", ".com.mx", ".com.ar"],
      cities: [
        "Madrid", "Barcelona", "Valencia", "Sevilla", "Zaragoza", "Málaga",
        "Murcia", "Palma", "Las Palmas", "Bilbao", "Alicante", "Córdoba",
      ],
      states: [
        "Andalucía", "Cataluña", "Comunidad de Madrid", "Comunidad Valenciana",
        "Galicia", "Castilla y León", "País Vasco", "Canarias", "Aragón",
      ],
      countries: [
        "España", "México", "Argentina", "Colombia", "Chile", "Perú",
      ],
      streetSuffixes: [
        "Calle", "Avenida", "Plaza", "Paseo", "Camino", "Carrera",
      ],
      phoneFormats: ["+34 ### ### ###", "### ### ###"],
      companyNames: [
        "Telefónica", "Santander", "Iberdrola", "Inditex", "BBVA", "Repsol",
      ],
      companySuffixes: ["S.A.", "S.L.", "S.L.U."],
      industries: [
        "Tecnología", "Salud", "Finanzas", "Educación", "Comercio",
      ],
      jobTitles: [
        "Desarrollador", "Director", "Analista", "Consultor", "Ingeniero",
      ],
      departments: [
        "Ingeniería", "Producto", "Diseño", "Marketing", "Ventas", "Finanzas",
      ],
      buzzwords: ["innovación", "transformación digital", "sostenibilidad"],
      catchPhrases: ["Calidad española"],
      loremWords: [
        "lorem", "ipsum", "dolor", "sit", "amet", "consectetur",
      ]
    )
  }

  // MARK: - Japanese Data

  private static func createJapanese() -> Self {
    Self(
      locale: .jaJP,
      firstNames: [
        "太郎", "花子", "一郎", "幸子", "健太", "美咲", "大輔", "さくら",
        "翔太", "愛", "隆", "恵", "誠", "麻衣", "智", "由美", "健一", "真由美",
        "拓也", "彩", "浩", "裕子", "直樹", "綾", "剛", "舞",
      ],
      lastNames: [
        "佐藤", "鈴木", "高橋", "田中", "渡辺", "伊藤", "山本", "中村",
        "小林", "加藤", "吉田", "山田", "佐々木", "山口", "松本", "井上",
        "木村", "林", "斎藤", "清水", "山崎", "森", "池田", "橋本",
      ],
      prefixes: ["様", "さん", "君", "ちゃん"],
      suffixes: [],
      emailDomains: [
        "gmail.com", "yahoo.co.jp", "docomo.ne.jp", "softbank.ne.jp",
      ],
      domainSuffixes: [".jp", ".co.jp", ".or.jp", ".ne.jp"],
      cities: [
        "東京", "大阪", "横浜", "名古屋", "札幌", "福岡", "神戸", "京都",
        "川崎", "さいたま", "広島", "仙台", "千葉", "北九州", "堺",
      ],
      states: [
        "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
      ],
      countries: ["日本", "アメリカ", "中国", "韓国", "台湾"],
      streetSuffixes: ["通り", "町", "丁目", "番地"],
      phoneFormats: ["0#-####-####", "+81 #-####-####"],
      companyNames: [
        "トヨタ", "ソニー", "ホンダ", "任天堂", "パナソニック", "日立",
      ],
      companySuffixes: ["株式会社", "有限会社", "合同会社"],
      industries: [
        "テクノロジー", "ヘルスケア", "金融", "教育", "小売",
      ],
      jobTitles: [
        "エンジニア", "マネージャー", "アナリスト", "ディレクター", "コンサルタント",
      ],
      departments: [
        "開発部", "製品部", "デザイン部", "マーケティング部", "営業部", "財務部",
      ],
      buzzwords: ["イノベーション", "DX", "クラウド", "AI"],
      catchPhrases: ["日本品質"],
      loremWords: [
        "lorem", "ipsum", "dolor", "sit", "amet", "consectetur",
      ]
    )
  }
}
