import Foundation

final class WeatherService {
  private static let cacheTTL: TimeInterval = 30 * 60

  private let networkClient: NetworkClient
  private var cachedSnapshot: WeatherSnapshot?
  private var cachedLocationKey: String?
  private var cachedAt: Date?

  init(networkClient: NetworkClient) {
    self.networkClient = networkClient
  }

  func invalidateCache() {
    cachedSnapshot = nil
    cachedLocationKey = nil
    cachedAt = nil
  }

  func currentWeather(for country: NewsCountry, locationQuery: String? = nil) async throws -> WeatherSnapshot {
    let locationKey = cacheKey(country: country, locationQuery: locationQuery)
    if let cachedSnapshot,
       cachedLocationKey == locationKey,
       let cachedAt,
       Date().timeIntervalSince(cachedAt) < Self.cacheTTL {
      return cachedSnapshot
    }

    let resolution = try await resolveLocationSource(country: country, locationQuery: locationQuery)
    let coords: (latitude: Double, longitude: Double)
    switch resolution {
    case .countryDefault(let fallbackCountry):
      coords = fallbackCountry.weatherCoordinates
    case .custom(let match):
      coords = (match.latitude, match.longitude)
    }

    let unit = country.usesFahrenheit ? "fahrenheit" : "celsius"
    let urlString = """
    https://api.open-meteo.com/v1/forecast?latitude=\(coords.latitude)&longitude=\(coords.longitude)\
    &current=temperature_2m,weather_code&temperature_unit=\(unit)&timezone=auto
    """
    let data = try await networkClient.fetchData(from: urlString)
    let snapshot = try Self.parse(data, usesFahrenheit: country.usesFahrenheit, locationSource: resolution)

    cachedSnapshot = snapshot
    cachedLocationKey = locationKey
    cachedAt = .now
    return snapshot
  }

  func resolveLocation(query: String, country: NewsCountry) async throws -> WeatherLocationMatch? {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return try await geocode(trimmed, countryCode: country.code)
  }

  private func cacheKey(country: NewsCountry, locationQuery: String?) -> String {
    let query = locationQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return "\(country.code)|\(query.lowercased())"
  }

  private func resolveLocationSource(
    country: NewsCountry,
    locationQuery: String?
  ) async throws -> WeatherLocationSource {
    if let query = locationQuery?.trimmingCharacters(in: .whitespacesAndNewlines),
       !query.isEmpty,
       let match = try await geocode(query, countryCode: country.code) {
      return .custom(match)
    }
    return .countryDefault(country)
  }

  private func geocode(_ query: String, countryCode: String) async throws -> WeatherLocationMatch? {
    guard var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search") else {
      return nil
    }
    components.queryItems = [
      URLQueryItem(name: "name", value: query),
      URLQueryItem(name: "count", value: "1"),
      URLQueryItem(name: "language", value: Locale.current.language.languageCode?.identifier ?? "es"),
      URLQueryItem(name: "country_code", value: countryCode),
      URLQueryItem(name: "format", value: "json"),
    ]
    guard let urlString = components.url?.absoluteString else { return nil }

    if let match = try await fetchGeocodeMatch(from: urlString) {
      return match
    }

    // Retry without country filter for ambiguous names near borders.
    components.queryItems = components.queryItems?.filter { $0.name != "country_code" }
    guard let fallbackURL = components.url?.absoluteString else { return nil }
    return try await fetchGeocodeMatch(from: fallbackURL)
  }

  private func fetchGeocodeMatch(from urlString: String) async throws -> WeatherLocationMatch? {
    let data = try await networkClient.fetchData(from: urlString)
    guard
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let results = json["results"] as? [[String: Any]],
      let first = results.first,
      let latitude = first["latitude"] as? Double,
      let longitude = first["longitude"] as? Double,
      let name = first["name"] as? String
    else {
      return nil
    }

    return WeatherLocationMatch(
      name: name,
      admin1: first["admin1"] as? String,
      admin2: first["admin2"] as? String,
      country: first["country"] as? String ?? "",
      latitude: latitude,
      longitude: longitude
    )
  }

  private static func parse(
    _ data: Data,
    usesFahrenheit: Bool,
    locationSource: WeatherLocationSource
  ) throws -> WeatherSnapshot {
    guard
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let current = json["current"] as? [String: Any],
      let temperature = current["temperature_2m"] as? Double,
      let weatherCode = current["weather_code"] as? Int
    else {
      throw NetworkError.decodingFailed
    }

    return WeatherSnapshot(
      temperature: Int(temperature.rounded()),
      weatherCode: weatherCode,
      usesFahrenheit: usesFahrenheit,
      locationSource: locationSource
    )
  }
}
