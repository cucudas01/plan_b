import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant.dart';

class GeminiService {
  static Future<List<Restaurant>> fetchRecommendations({
    required double lat, required double lng, required String apiKey,
  }) async {
    // 1. [사용자 취향 학습] 저장된 식당 카테고리 분석
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> saved = jsonDecode(prefs.getString('saved_restaurants') ?? '[]');
    String preferences = saved.map((e) => e['category']).toSet().join(', ');

    List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
    String cityName = placemarks.first.locality ?? '이 도시';

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');

    // 2. [대기 예측 고도화] 상세 데이터를 요구하는 프롬프트 수정
    final prompt = '''
      현재 $cityName($lat,$lng) 근처 맛집 10곳을 추천해줘. 
      사용자 선호 카테고리: [$preferences]. 취향을 고려하되 새로운 곳도 섞어줘.
      JSON 배열로만 응답해. 
      필드: region, category, name, rating, reviews, price, opentime, tips, 
      waiting(현재 요일/시간 기준 예상 대기 상황과 이유), lat, lng
    ''';

    final response = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]}));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      String rawText = jsonResponse['candidates'][0]['content']['parts'][0]['text'];

      // JSON 부분만 추출
      int start = rawText.indexOf('[');
      int end = rawText.lastIndexOf(']') + 1;
      if (start == -1 || end == 0) throw Exception("잘못된 AI 응답 형식");

      String jsonText = rawText.substring(start, end);
      List<dynamic> parsedJson = json.decode(jsonText);

      return parsedJson.map((item) => Restaurant(
        name: item['name'] ?? '정보 없음',
        category: item['category'] ?? '식당',
        region: item['region'] ?? cityName,
        rating: (item['rating'] ?? 0.0).toDouble(),
        reviews: item['reviews'] ?? 0,
        price: item['price'] ?? 0,
        address: item['region'] ?? '',
        lat: (item['lat'] ?? 0.0).toDouble(),
        lng: (item['lng'] ?? 0.0).toDouble(),
        isOpen: true,
        opentime: item['opentime'] ?? '',
        tips: item['tips'] ?? '',
        waiting: item['waiting'] ?? '대기 정보 없음',
        link: '',
        image: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=400',
        distance: Geolocator.distanceBetween(lat, lng, (item['lat'] ?? 0.0).toDouble(), (item['lng'] ?? 0.0).toDouble()),
      )).toList();
    }
    throw Exception("AI 연결 실패");
  }
}