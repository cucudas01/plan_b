import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/restaurant.dart';

class PlacesService {
  static const String baseUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  static Future<List<Restaurant>> getNearbyRestaurants(
      double lat, double lng, String apiKey) async {
    final url = Uri.parse('$baseUrl?location=$lat,$lng&radius=1500&type=restaurant&key=$apiKey');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List results = data['results'] ?? [];

      // 1. 모델 변환 2. 평점 3.8 이상 필터링
      return results
          .map((item) => Restaurant.fromPlaces(item, lat, lng))
          .where((res) => res.rating >= 3.8)
          .toList();
    } else {
      throw Exception('Places API 연결 실패 (${response.statusCode})');
    }
  }
}