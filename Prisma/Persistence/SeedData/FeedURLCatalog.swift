import Foundation

/// URLs alternativas cuando el feed principal deja de responder o devuelve HTML vacío.
enum FeedURLCatalog {
  private static let alternatesByID: [String: [String]] = [
    // X — puentes inestables; el fallback del JSON tiene prioridad vía RecommendedFeed.fallbackFeedURL
    "x-ap": ["https://www.theguardian.com/world/rss"],
    "x-reuters": ["https://feeds.bbci.co.uk/news/world/rss.xml"],
    "x-bbcbreaking": ["https://feeds.bbci.co.uk/news/rss.xml"],
    "x-elpais": ["https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada"],
    "x-elmundo": ["https://e00-elmundo.uecdn.es/elmundo/rss/portada.xml"],
    "x-abc": ["https://www.abc.es/rss/feeds/abc_ultima.xml"],
    "x-techcrunch": ["https://techcrunch.com/feed/"],
    "x-verge": ["https://www.theverge.com/rss/index.xml"],
    "x-trends-world": ["https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en"],
    "x-trends-spain": ["https://news.google.com/rss?hl=es&gl=ES&ceid=ES:es"],

    // España
    "as": [
      "https://as.com/rss/tags/ultimas_noticias.xml",
      "https://feeds.as.com/mrss-s/pages/ep/site/as.com/portada",
    ],
    "sport": [
      "https://www.sport.es/es/rss/futbol/rss.xml",
      "https://www.sport.es/es/rss/portada/rss.xml",
    ],
    "publico-es": [
      "https://www.publico.es/rss/",
      "https://www.publico.es/rss/portada/",
    ],
    "rtve-es": [
      "https://www.rtve.es/rss/temas_noticias.xml",
      "https://www.rtve.es/rss/temas_espana.xml",
    ],
    "meristation": [
      "https://www.vidaextra.com/index.xml",
      "https://www.meristation.com/rss/news.xml",
    ],
    "ccma-324-cat": [
      "https://news.google.com/rss/search?q=site:3cat.cat&hl=ca&gl=ES&ceid=ES:ca",
      "https://www.ara.cat/rss/",
    ],
    "catalunya-radio": [
      "https://www.catalunyaplural.cat/ca/rss.xml",
      "https://news.google.com/rss/search?q=324.cat&hl=ca&gl=ES&ceid=ES:ca",
    ],
    "lasexta-es": ["https://www.lasexta.com/rss/348128.xml"],

    // Internacional / US / UK
    "reuters-int": [
      "https://feeds.reuters.com/reuters/worldNews",
      "https://feeds.bbci.co.uk/news/world/rss.xml",
    ],
    "ap-us": [
      "https://apnews.com/index.rss",
      "https://news.google.com/rss/search?q=site:apnews.com&hl=en&gl=US&ceid=US:en",
    ],
    "cnn-us": [
      "https://rss.cnn.com/rss/cnn_topstories.rss",
      "https://rss.cnn.com/rss/edition.rss",
    ],
    "scientificamerican-int": [
      "https://rss.sciam.com/ScientificAmerican-Global",
      "https://www.scientificamerican.com/feed/",
    ],
    "euronews-int": ["https://www.euronews.com/rss"],

    // México
    "el-universal-mx": ["https://www.eluniversal.com.mx/rss.xml"],
    "animal-politico": [
      "https://www.animalpolitico.com/feed/",
      "https://animalpolitico.com/feed/",
    ],
    "milenio-mx": ["https://www.milenio.com/rss"],
    "proceso-mx": ["https://www.proceso.com.mx/rss"],
    "excelsior-mx": ["https://www.excelsior.com.mx/rss.xml"],
    "jornada-mx": ["https://www.jornada.com.mx/rss/"],
    "eleconomista-mx": ["https://www.eleconomista.com.mx/rss/"],

    // Argentina
    "infobae-ar": ["https://www.infobae.com/arc/outboundfeeds/rss/"],
    "pagina12-ar": [
      "https://www.pagina12.com.ar/rss/secciones/el-pais/notas",
      "https://www.pagina12.com.ar/rss/portada",
    ],

    // Chile
    "latercera-cl": [
      "https://www.latercera.com/arc/outboundfeeds/rss/",
      "https://www.latercera.com/feed/",
    ],
    "biobio-cl": ["https://www.biobiochile.cl/listado/rss"],
    "cooperativa-cl": [
      "https://www.cooperativa.cl/rss/site/tax/portada/portada.xml",
    ],
    "df-cl": ["https://www.df.cl/rss"],
    "emol-cl": ["https://www.emol.com/rss/rss.aspx?tipo=1"],

    // Colombia
    "elespectador-co": ["https://www.elespectador.com/rss.xml"],
    "semana-co": ["https://www.semana.com/rss/"],
    "portafolio-co": ["https://www.portafolio.co/rss"],
    "rcn-co": ["https://www.rcnradio.com/rss"],

    // Perú
    "elcomercio-pe": [
      "https://elcomercio.pe/arc/outboundfeeds/rss/",
    ],
    "larepublica-pe": ["https://larepublica.pe/rss/"],
    "gestion-pe": ["https://gestion.pe/rss/"],

    // Portugal
    "publico-pt": [
      "https://www.publico.pt/rss",
      "https://www.publico.pt/rss/noticias",
    ],
    "expresso-pt": ["https://feeds.feedburner.com/expresso"],
    "dn-pt": ["https://www.dn.pt/rss/"],

    // Brasil
    "uol-br": ["https://rss.uol.com.br/feed/index.xml"],
    "estadao-br": ["https://www.estadao.com.br/rss/"],

    // Francia
    "lequipe-fr": ["https://www.lequipe.fr/rss/actu_rss.xml"],
    "leparisien-fr": ["https://www.leparisien.fr/arc/outboundfeeds/rss/"],
    "20minutes-fr": ["https://www.20minutes.fr/rss/une.xml"],

    // Italia
    "ilpost-it": ["https://www.ilpost.it/feed/"],

    // Catalunya
    "el-nacional-cat": ["https://www.elnacional.cat/rss/"],
    "segre-cat": ["https://www.segre.com/rss/"],
    "nacio-digital-cat": ["https://www.naciodigital.cat/feed/"],

    // Castilla y León / prensa regional ES (Vocento/Prensa Ibérica sin RSS nativo)
    "diario-palentino-es": ["https://www.diariopalentino.es/rss/"],
    "el-norte-castilla-es": [
      "https://www.elnortedecastilla.es/rss/",
      "https://www.nortecastilla.es/rss/",
    ],
    "diario-leon-es": ["https://www.diariodeleon.es/rss/"],
    "diario-burgos-es": ["https://www.diariodeburgos.es/rss/"],
    "diario-avila-es": ["https://www.diariodeavila.es/rss/"],
    "la-gaceta-salamanca-es": ["https://www.lagacetadesalamanca.es/rss/"],
    "faro-vigo-es": ["https://www.faro.es/rss/"],
    "lavoz-galicia-es": ["https://www.lavozdegalicia.es/rss/"],
    "canarias7-es": ["https://www.canarias7.es/rss/"],
    "las-provincias-es": ["https://www.lasprovincias.es/rss/"],
    "el-comercio-es": ["https://www.elcomercio.es/rss/"],
    "la-rioja-es": ["https://www.larioja.com/rss/"],
    "el-diario-montanes-es": ["https://www.eldiariomontanes.es/rss/"],
    "la-verdad-es": ["https://www.laverdad.es/rss/"],
    "diario-sur-es": ["https://www.diariosur.es/rss/"],
    "ideal-granada-es": ["https://www.ideal.es/rss/"],
    "hoy-extremadura-es": ["https://www.hoy.es/rss/"],
    "diario-navarra-es": ["https://www.diariodenavarra.es/rss/"],
    "menorca-info-es": ["https://www.menorca.info/rss/"],
    "diario-vasco-es": ["https://www.diariovasco.com/rss/"],
    "deia-eus": ["https://www.deia.eus/rss/"],

    // Francia regional
    "la-montagne-fr": ["https://www.lamontagne.fr/rss/"],
    "le-progres-fr": ["https://www.leprogres.fr/rss/une.xml"],
    "nice-matin-fr": ["https://www.nicematin.com/rss/"],
    "la-provence-fr": ["https://www.laprovence.com/rss/"],
    "le-telegramme-fr": ["https://www.letelegramme.fr/rss/"],
    "la-depeche-fr": ["https://www.ladepeche.fr/rss/"],

    // Alemania regional
    "waz-de": ["https://www.waz.de/rss/"],
    "ksta-de": ["https://www.ksta.de/rss/"],
    "abendblatt-de": ["https://www.abendblatt.de/rss/"],
    "merkur-de": ["https://www.merkur.de/rss/"],
    "stuttgarter-zeitung-de": ["https://www.stuttgarter-zeitung.de/rss/"],
    "rp-online-de": ["https://rp-online.de/rss/"],
    "westfalen-blatt-de": ["https://www.westfalen-blatt.de/rss/"],

    // Italia
    "il-giornale-it": ["https://www.ilgiornale.it/rss/home.xml"],
    "la-stampa-it": ["https://www.lastampa.it/rss/home.xml"],

    // Portugal / Canadá / LATAM / APAC
    "jn-pt": ["https://www.jn.pt/rss.xml"],
    "la-presse-ca": ["https://www.lapresse.ca/rss/"],
    "le-devoir-ca": ["https://www.ledevoir.com/rss/"],
    "el-deber-bo": ["https://eldeber.com.bo/rss/"],
    "elpais-uy": ["https://www.elpais.com.uy/rss/"],
    "laprensa-hn": ["https://www.laprensa.hn/rss/"],
    "korea-herald-kr": ["https://www.koreaherald.com/rss/newsAll.xml"],
    "nz-herald": ["https://www.nzherald.co.nz/arc/outboundfeeds/rss/"],
    "nzz-ch": ["https://www.nzz.ch/rss/"],
    "bazonline-ch": ["https://www.bazonline.ch/rss/"],
    "tagesanzeiger-ch": ["https://www.tagesanzeiger.ch/rss/"],
    "le-temps-ch": ["https://www.letemps.ch/rss/"],
    "24heures-ch": ["https://www.24heures.ch/rss/"],
    "cdt-ch": ["https://www.cdt.ch/rss/"],
  ]

  static func alternateURLs(for feed: RecommendedFeed) -> [URL] {
    var urls: [String] = []
    if let fallback = feed.fallbackFeedURL {
      urls.append(fallback)
    }
    if let mapped = alternatesByID[feed.id] {
      urls.append(contentsOf: mapped)
    }
    return deduplicatedURLs(urls)
  }

  static func alternateURLs(matching source: FeedSource) -> [URL] {
    guard let feed = RecommendedFeeds.matching(source) else { return [] }
    return alternateURLs(for: feed)
  }

  static func alternateURLs(forCatalogID id: String) -> [URL] {
    guard let mapped = alternatesByID[id] else { return [] }
    return deduplicatedURLs(mapped)
  }

  private static func deduplicatedURLs(_ strings: [String]) -> [URL] {
    var seen = Set<String>()
    return strings.compactMap { raw in
      guard seen.insert(raw).inserted else { return nil }
      return URL(string: raw)
    }
  }
}
