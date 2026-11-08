//
//  WeatherService.swift
//  VT FOMO
//
//  Fetches the forecast for an event's location and start time.
//
//  This satisfies the networking requirement: it is a live REST call to data
//  that changes over time. We use Open-Meteo because it needs no API key,
//  which keeps the project runnable straight out of the zip file with no
//  manual setup.
//
//  Offline behaviour: every successful response is written to UserDefaults
//  keyed by location + hour. If the network is unavailable we return the
//  cached value and mark it stale so the UI can say so.
//

import Foundation

// MARK: - Model

struct EventWeather: Codable, Equatable {
    var temperatureF: Double
    var precipitationChance: Int
    var weatherCode: Int
    var fetchedAt: Date
    /// True when this came from the cache because the network failed.
    var isStale: Bool = false

    /// Maps the WMO weather code to an SF Symbol.
    var symbolName: String {
        switch weatherCode {
        case 0:        return "sun.max.fill"
        case 1, 2:     return "cloud.sun.fill"
        case 3:        return "cloud.fill"
        case 45, 48:   return "cloud.fog.fill"
        case 51...67:  return "cloud.drizzle.fill"
        case 71...77:  return "cloud.snow.fill"
        case 80...82:  return "cloud.heavyrain.fill"
        case 95...99:  return "cloud.bolt.rain.fill"
        default:       return "cloud.fill"
        }
    }

    var description: String {
        switch weatherCode {
        case 0:        return "Clear"
        case 1, 2:     return "Partly cloudy"
        case 3:        return "Overcast"
        case 45, 48:   return "Fog"
        case 51...67:  return "Rain"
        case 71...77:  return "Snow"
        case 80...82:  return "Showers"
        case 95...99:  return "Thunderstorms"
        default:       return "Mixed"
        }
    }

    var summaryLine: String {
        "\(Int(temperatureF.rounded()))°F · \(description) · \(precipitationChance)% rain"
    }
}

// MARK: - Service

@Observable
final class WeatherService {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(EventWeather)
        case unavailable
    }

    private(set) var state: LoadState = .idle

    /// Shape of the Open-Meteo response. Only the fields we need.
    private struct APIResponse: Decodable {
        struct Hourly: Decodable {
            let time: [String]
            let temperature_2m: [Double]
            let precipitation_probability: [Int]
            let weather_code: [Int]
        }
        let hourly: Hourly
    }

    /// Fetches the forecast for the hour containing `date`.
    @MainActor
    func load(latitude: Double, longitude: Double, at date: Date) async {
        state = .loading
        let key = Self.cacheKey(latitude: latitude, longitude: longitude, date: date)

        // Open-Meteo only forecasts about 16 days out. Anything further and
        // there is nothing meaningful to show.
        guard date.timeIntervalSinceNow < 60 * 60 * 24 * 15 else {
            state = .unavailable
            return
        }

        do {
            let weather = try await fetch(latitude: latitude, longitude: longitude, at: date)
            Self.writeCache(weather, key: key)
            state = .loaded(weather)
        } catch {
            // Requirement NFR-4: fall back to what we already had.
            if var cached = Self.readCache(key: key) {
                cached.isStale = true
                state = .loaded(cached)
            } else {
                state = .unavailable
            }
        }
    }

    // MARK: - Networking

    private func fetch(latitude: Double, longitude: Double, at date: Date) async throws -> EventWeather {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,weather_code"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "timezone", value: "America/New_York"),
            URLQueryItem(name: "forecast_days", value: "16")
        ]

        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)

        // The API returns hourly arrays with timestamps like "2026-09-18T19:00".
        // Find the index closest to the event's start hour.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = TimeZone(identifier: "America/New_York")

        // FUNCTIONAL: build (index, distance) pairs and pick the smallest.
        let target = date.timeIntervalSince1970
        let best = decoded.hourly.time
            .enumerated()
            .compactMap { index, stamp -> (Int, Double)? in
                guard let parsed = formatter.date(from: stamp) else { return nil }
                return (index, abs(parsed.timeIntervalSince1970 - target))
            }
            .min(by: { $0.1 < $1.1 })

        guard let index = best?.0,
              index < decoded.hourly.temperature_2m.count,
              index < decoded.hourly.precipitation_probability.count,
              index < decoded.hourly.weather_code.count else {
            throw URLError(.cannotParseResponse)
        }

        return EventWeather(
            temperatureF: decoded.hourly.temperature_2m[index],
            precipitationChance: decoded.hourly.precipitation_probability[index],
            weatherCode: decoded.hourly.weather_code[index],
            fetchedAt: Date()
        )
    }

    // MARK: - Cache

    private static func cacheKey(latitude: Double, longitude: Double, date: Date) -> String {
        let hour = Int(date.timeIntervalSince1970 / 3600)
        // Round the coordinate so nearby events share a cache entry.
        return String(format: "wx.%.2f.%.2f.%d", latitude, longitude, hour)
    }

    private static func writeCache(_ weather: EventWeather, key: String) {
        guard let data = try? JSONEncoder().encode(weather) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func readCache(key: String) -> EventWeather? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(EventWeather.self, from: data)
    }
}
