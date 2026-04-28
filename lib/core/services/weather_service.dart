import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherModel {
  final double temperature;
  final int weatherCode;
  final double windSpeed;
  final int humidity;
  final String cityName;
  final DateTime fetchedAt;

  const WeatherModel({
    required this.temperature,
    required this.weatherCode,
    required this.windSpeed,
    required this.humidity,
    required this.cityName,
    required this.fetchedAt,
  });

  bool get isStale => DateTime.now().difference(fetchedAt).inMinutes > 30;

  String get description {
    if (weatherCode == 0) return 'Açık Hava';
    if (weatherCode <= 3) return 'Parçalı Bulutlu';
    if (weatherCode <= 48) return 'Sisli';
    if (weatherCode <= 55) return 'Çisenti';
    if (weatherCode <= 65) return 'Yağmurlu';
    if (weatherCode <= 75) return 'Karlı';
    if (weatherCode <= 82) return 'Sağanak Yağış';
    if (weatherCode <= 99) return 'Fırtına';
    return 'Bilinmiyor';
  }

  IconData get icon {
    if (weatherCode == 0) return Icons.wb_sunny;
    if (weatherCode <= 2) return Icons.wb_cloudy;
    if (weatherCode == 3) return Icons.cloud;
    if (weatherCode <= 48) return Icons.foggy;
    if (weatherCode <= 55) return Icons.grain;
    if (weatherCode <= 65) return Icons.water_drop;
    if (weatherCode <= 75) return Icons.ac_unit;
    if (weatherCode <= 82) return Icons.water;
    return Icons.thunderstorm;
  }

  Color get iconColor {
    if (weatherCode == 0) return const Color(0xFFFFA000);
    if (weatherCode <= 3) return const Color(0xFF78909C);
    if (weatherCode <= 48) return const Color(0xFF90A4AE);
    if (weatherCode <= 65) return const Color(0xFF42A5F5);
    if (weatherCode <= 75) return const Color(0xFFB0BEC5);
    if (weatherCode <= 82) return const Color(0xFF1E88E5);
    return const Color(0xFF7B1FA2);
  }

  List<Color> get gradientColors {
    if (weatherCode == 0) return [const Color(0xFF1565C0), const Color(0xFF42A5F5)];
    if (weatherCode <= 3) return [const Color(0xFF37474F), const Color(0xFF546E7A)];
    if (weatherCode <= 48) return [const Color(0xFF455A64), const Color(0xFF607D8B)];
    if (weatherCode <= 65) return [const Color(0xFF1565C0), const Color(0xFF1976D2)];
    if (weatherCode <= 75) return [const Color(0xFF37474F), const Color(0xFF78909C)];
    if (weatherCode <= 82) return [const Color(0xFF0D47A1), const Color(0xFF1565C0)];
    return [const Color(0xFF4A148C), const Color(0xFF6A1B9A)];
  }
}

enum WeatherStatus { loading, success, locationDenied, locationDisabled, error }

class WeatherService {
  static final instance = WeatherService._();
  WeatherService._();

  WeatherModel? _cached;

  Future<({WeatherModel? data, WeatherStatus status})> getWeather() async {
    if (_cached != null && !_cached!.isStale) {
      return (data: _cached, status: WeatherStatus.success);
    }

    final posResult = await _getPosition();
    if (posResult.status != WeatherStatus.success || posResult.position == null) {
      return (data: _cached, status: posResult.status);
    }

    try {
      final weather = await _fetchWeather(
        posResult.position!.latitude,
        posResult.position!.longitude,
      );
      _cached = weather;
      return (data: weather, status: WeatherStatus.success);
    } catch (_) {
      return (data: _cached, status: WeatherStatus.error);
    }
  }

  Future<({Position? position, WeatherStatus status})> _getPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return (position: null, status: WeatherStatus.locationDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return (position: null, status: WeatherStatus.locationDenied);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return (position: null, status: WeatherStatus.locationDenied);
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (position: pos, status: WeatherStatus.success);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return (position: last, status: WeatherStatus.success);
      return (position: null, status: WeatherStatus.error);
    }
  }

  Future<WeatherModel> _fetchWeather(double lat, double lon) async {
    final latStr = lat.toStringAsFixed(4);
    final lonStr = lon.toStringAsFixed(4);

    final weatherUri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latStr&longitude=$lonStr'
      '&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m'
      '&timezone=auto',
    );

    final geoUri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=$latStr&lon=$lonStr&format=json&accept-language=tr',
    );

    // 10 sn timeout + statusCode guard — Open-Meteo / Nominatim yanıt
    // vermezse uygulama hava durumu kartında sonsuza kadar yüklenmesin.
    const timeout = Duration(seconds: 10);
    final responses = await Future.wait([
      http.get(weatherUri).timeout(timeout),
      http.get(geoUri, headers: {
        'User-Agent': 'CiftlikPro/1.0',
        'Accept-Language': 'tr',
      }).timeout(timeout),
    ]);

    if (responses[0].statusCode != 200) {
      throw Exception('Hava durumu servisi yanıt vermedi (${responses[0].statusCode})');
    }
    if (responses[1].statusCode != 200) {
      throw Exception('Konum servisi yanıt vermedi (${responses[1].statusCode})');
    }

    final weatherData = jsonDecode(responses[0].body) as Map<String, dynamic>;
    final geoData = jsonDecode(responses[1].body) as Map<String, dynamic>;

    final current = weatherData['current'] as Map<String, dynamic>;
    final address = geoData['address'] as Map<String, dynamic>? ?? {};
    final city = address['city'] as String? ??
        address['town'] as String? ??
        address['village'] as String? ??
        address['county'] as String? ??
        'Konum';

    return WeatherModel(
      temperature: (current['temperature_2m'] as num).toDouble(),
      weatherCode: current['weather_code'] as int,
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      humidity: current['relative_humidity_2m'] as int,
      cityName: city,
      fetchedAt: DateTime.now(),
    );
  }
}
