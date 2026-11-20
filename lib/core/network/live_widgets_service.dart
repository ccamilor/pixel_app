import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'browser_geolocation.dart';

/// Datos de clima y ubicación actuales.
class WeatherInfo {
  const WeatherInfo({
    required this.locationLabel,
    required this.temperatureC,
    required this.conditionLabel,
    required this.weatherCode,
  });

  final String locationLabel;
  final double temperatureC;
  final String conditionLabel;
  final int weatherCode;
}

/// Partido / resultado deportivo de América de Cali o Ligas Europeas.
class MatchSummary {
  const MatchSummary({
    required this.league,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.statusLabel,
    required this.isAmericaDeCali,
    required this.hasStarted,
    this.kickoffTime24h,
  });

  final String league;
  final String homeTeam;
  final String awayTeam;
  final String homeScore;
  final String awayScore;
  final String statusLabel;
  final bool isAmericaDeCali;
  final bool hasStarted;
  final String? kickoffTime24h;

  /// Si ya empezó muestra marcador (`A 2-1 B`), si no ha iniciado muestra `A vs B` sin marcador.
  String get headline =>
      hasStarted ? '$homeTeam $homeScore-$awayScore $awayTeam' : '$homeTeam vs $awayTeam';

  String get subDetail =>
      hasStarted ? statusLabel : (kickoffTime24h ?? statusLabel);
}

/// Servicio ligero sin API keys para Clima (Open-Meteo + GPS/Ciudad manual) y Fútbol (ESPN API pública).
class LiveWidgetsService {
  static const _timeout = Duration(seconds: 6);
  static const _prefCityKey = 'pixel_weather_city';
  static const _prefLatKey = 'pixel_weather_lat';
  static const _prefLonKey = 'pixel_weather_lon';

  /// Guarda una ciudad elegida manualmente por el usuario (buscada con Open-Meteo Geocoding).
  static Future<bool> setManualCity(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return false;

    final geoUri = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeQueryComponent(trimmed)}&count=1&language=es&format=json',
    );
    final res = await http.get(geoUri).timeout(_timeout);
    if (res.statusCode != 200) return false;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>? ?? const []);
    if (results.isEmpty) return false;

    final first = results.first as Map<String, dynamic>;
    final name = (first['name'] ?? trimmed).toString();
    final country = (first['country_code'] ?? '').toString();
    final lat = (first['latitude'] as num).toDouble();
    final lon = (first['longitude'] as num).toDouble();
    final label = country.isNotEmpty ? '$name, $country' : name;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCityKey, label);
    await prefs.setDouble(_prefLatKey, lat);
    await prefs.setDouble(_prefLonKey, lon);
    return true;
  }

  /// Borra la ciudad manual para volver a usar GPS automático.
  static Future<void> clearManualCity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefCityKey);
    await prefs.remove(_prefLatKey);
    await prefs.remove(_prefLonKey);
  }

  /// Obtiene clima actual con prioridad: 1) Ciudad guardada, 2) GPS del navegador, 3) IP, 4) Cali, CO.
  static Future<WeatherInfo> fetchWeather() async {
    double lat = 3.4516;
    double lon = -76.5320;
    String city = 'Cali, CO';
    bool resolved = false;

    // 1. Prioridad: ciudad fijada manualmente por el usuario
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCity = prefs.getString(_prefCityKey);
      final savedLat = prefs.getDouble(_prefLatKey);
      final savedLon = prefs.getDouble(_prefLonKey);
      if (savedCity != null && savedLat != null && savedLon != null) {
        city = savedCity;
        lat = savedLat;
        lon = savedLon;
        resolved = true;
      }
    } catch (_) {}

    // 2. Prioridad: GPS real del navegador (alta precisión) + geocodificación inversa
    if (!resolved) {
      final gps = await getBrowserCoordinates();
      if (gps != null) {
        lat = gps.lat;
        lon = gps.lon;
        resolved = true;
        city = await _reverseGeocode(lat, lon) ?? 'Tu ubicación';
      }
    }

    // 3. Fallback: geolocalización por IP
    if (!resolved) {
      try {
        final geoRes = await http
            .get(Uri.parse('https://get.geojs.io/v1/ip/geo.json'))
            .timeout(_timeout);
        if (geoRes.statusCode == 200) {
          final geo = jsonDecode(geoRes.body) as Map<String, dynamic>;
          final parsedLat = double.tryParse('${geo['latitude'] ?? ''}');
          final parsedLon = double.tryParse('${geo['longitude'] ?? ''}');
          final geoCity = (geo['city'] ?? '').toString().trim();
          final geoCountry = (geo['country_code'] ?? '').toString().trim();
          if (parsedLat != null && parsedLon != null) {
            lat = parsedLat;
            lon = parsedLon;
          }
          if (geoCity.isNotEmpty) {
            city = geoCountry.isNotEmpty ? '$geoCity, $geoCountry' : geoCity;
          }
        }
      } catch (_) {}
    }

    final weatherUrl = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code&timezone=auto',
    );
    final res = await http.get(weatherUrl).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Sin conexión al servicio de clima');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>;
    final temp = (current['temperature_2m'] as num).toDouble();
    final code = (current['weather_code'] as num).toInt();

    return WeatherInfo(
      locationLabel: city,
      temperatureC: temp,
      conditionLabel: _weatherCodeToSpanish(code),
      weatherCode: code,
    );
  }

  static Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=es',
      );
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final city = (data['city'] ?? data['locality'] ?? '').toString().trim();
      final country = (data['countryCode'] ?? '').toString().trim();
      if (city.isEmpty) return null;
      return country.isNotEmpty ? '$city, $country' : city;
    } catch (_) {
      return null;
    }
  }

  /// Obtiene partidos recientes/en vivo de América de Cali (Liga BetPlay) y Ligas Europeas.
  static Future<List<MatchSummary>> fetchSportsFeed() async {
    const endpoints = <({String league, String slug})>[
      (league: 'Liga BetPlay', slug: 'col.1'),
      (league: 'Champions', slug: 'uefa.champions'),
      (league: 'LaLiga', slug: 'esp.1'),
      (league: 'Premier League', slug: 'eng.1'),
      (league: 'Serie A', slug: 'ita.1'),
    ];

    final americaMatches = <MatchSummary>[];
    final europeMatches = <MatchSummary>[];

    await Future.wait(
      endpoints.map((ep) async {
        try {
          final uri = Uri.parse(
            'https://site.api.espn.com/apis/site/v2/sports/soccer/${ep.slug}/scoreboard',
          );
          final res = await http.get(uri).timeout(_timeout);
          if (res.statusCode != 200) return;

          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final events = (json['events'] as List<dynamic>? ?? const []);

          for (final rawEvent in events) {
            final event = rawEvent as Map<String, dynamic>;
            final competitions =
                (event['competitions'] as List<dynamic>? ?? const []);
            if (competitions.isEmpty) continue;
            final comp = competitions.first as Map<String, dynamic>;
            final competitors =
                (comp['competitors'] as List<dynamic>? ?? const []);
            if (competitors.length < 2) continue;

            final home = competitors.firstWhere(
              (c) => (c as Map<String, dynamic>)['homeAway'] == 'home',
              orElse: () => competitors[0],
            ) as Map<String, dynamic>;
            final away = competitors.firstWhere(
              (c) => (c as Map<String, dynamic>)['homeAway'] == 'away',
              orElse: () => competitors[1],
            ) as Map<String, dynamic>;

            final homeName =
                ((home['team'] as Map<String, dynamic>?)?['shortDisplayName'] ??
                        'Local')
                    .toString();
            final awayName =
                ((away['team'] as Map<String, dynamic>?)?['shortDisplayName'] ??
                        'Visitante')
                    .toString();
            final homeScore = (home['score'] ?? '-').toString();
            final awayScore = (away['score'] ?? '-').toString();
            final statusObj =
                ((event['status'] as Map<String, dynamic>?)?['type']
                    as Map<String, dynamic>?);
            final state = (statusObj?['state'] ?? 'pre').toString();
            final hasStarted = state == 'in' || state == 'post';
            final statusLabel =
                (statusObj?['shortDetail'] ?? statusObj?['description'] ?? '')
                    .toString();

            String? kickoff24h;
            final rawDate = (event['date'] ?? '').toString();
            final parsedDate = DateTime.tryParse(rawDate)?.toLocal();
            if (parsedDate != null) {
              kickoff24h = DateFormat('dd/MM HH:mm').format(parsedDate);
            }

            final combinedLower = '$homeName $awayName'.toLowerCase();
            final isAmerica = combinedLower.contains('américa') ||
                combinedLower.contains('america de cali') ||
                (ep.slug == 'col.1' && combinedLower.contains('america'));

            final match = MatchSummary(
              league: ep.league,
              homeTeam: homeName,
              awayTeam: awayName,
              homeScore: homeScore,
              awayScore: awayScore,
              statusLabel: statusLabel,
              isAmericaDeCali: isAmerica,
              hasStarted: hasStarted,
              kickoffTime24h: kickoff24h,
            );

            if (isAmerica) {
              americaMatches.add(match);
            } else if (ep.slug != 'col.1') {
              europeMatches.add(match);
            }
          }
        } catch (_) {
          // Ignora fallo individual de una liga para no romper el resto
        }
      }),
    );

    return [
      ...americaMatches,
      ...europeMatches.take(8),
    ];
  }

  static String _weatherCodeToSpanish(int code) {
    if (code == 0) return 'Despejado';
    if (code <= 3) return 'Parcialmente nublado';
    if (code <= 48) return 'Neblina';
    if (code <= 57) return 'Llovizna';
    if (code <= 67) return 'Lluvia';
    if (code <= 82) return 'Chubascos';
    if (code >= 95) return 'Tormenta';
    return 'Nublado';
  }
}

final weatherInfoProvider = FutureProvider<WeatherInfo>(
  (_) => LiveWidgetsService.fetchWeather(),
);

final sportsFeedProvider = FutureProvider<List<MatchSummary>>(
  (_) => LiveWidgetsService.fetchSportsFeed(),
);
