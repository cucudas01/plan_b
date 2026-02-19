import 'dart:convert';
import 'package:flutter/foundation.dart'; // debugPrint를 위해 필요
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant.dart';

class GeminiService {
  static Future<List<Restaurant>> fetchRecommendations({
    required double lat,
    required double lng,
    required String apiKey,
  }) async {
    // 1. [사용자 취향 학습] 저장된 식당 카테고리 분석
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> saved = jsonDecode(prefs.getString('saved_restaurants') ?? '[]');
    String preferences = saved.map((e) => e['category']).toSet().join(', ');

    // 현재 위치 좌표를 기반으로 도시 이름(지역명) 획득
    List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
    String cityName = placemarks.first.locality ?? '이 도시';

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');

    // 2. [데이터 타입 명시] AI에게 숫자 필드는 따옴표 없는 숫자로 줄 것을 강력하게 요청
    final prompt = '''
      현재 $cityName($lat,$lng) 근처 맛집 10곳을 추천해줘. 
      사용자 선호 카테고리: [$preferences]. 취향을 고려하되 새로운 곳도 섞어줘.
      JSON 배열로만 응답해. 
      
      필드별 타입 가이드:
      - name, category, region, opentime, tips, waiting: 문자열(String)
      - rating: 숫자(double, 예: 4.5)
      - reviews: 숫자(int, 예: 120)
      - price: 숫자(int, 예: 15000)
      - lat, lng: 숫자(double, 예: 34.123)
      - waiting 필드에는 현재 요일/시간 기준 예상 대기 상황과 이유를 상세히 적어줘.
    ''';

    final response = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }));

    // 에러 발생 시 상세 정보 출력
    if (response.statusCode != 200) {
      debugPrint('--- Gemini API 호출 실패 ---');
      debugPrint('상태 코드: ${response.statusCode}');
      debugPrint('응답 내용: ${response.body}');
      throw Exception("AI 연결 실패");
    }

    final jsonResponse = jsonDecode(response.body);
    String rawText = jsonResponse['candidates'][0]['content']['parts'][0]['text'];

    // JSON 부분만 추출
    int start = rawText.indexOf('[');
    int end = rawText.lastIndexOf(']') + 1;
    if (start == -1 || end == 0) throw Exception("잘못된 AI 응답 형식");

    String jsonText = rawText.substring(start, end);
    List<dynamic> parsedJson = json.decode(jsonText);

    return parsedJson.map((item) {
      // 3. [안전한 파싱] AI가 문자열로 숫자를 보내도 에러가 나지 않도록 변환 로직 추가
      // .toString()으로 먼저 변환 후 tryParse를 사용하여 타입 에러를 원천 차단합니다.
      final rLat = double.tryParse(item['lat']?.toString() ?? '0.0') ?? 0.0;
      final rLng = double.tryParse(item['lng']?.toString() ?? '0.0') ?? 0.0;
      final rRating = double.tryParse(item['rating']?.toString() ?? '0.0') ?? 0.0;
      final rReviews = int.tryParse(item['reviews']?.toString() ?? '0') ?? 0;
      final rPrice = int.tryParse(item['price']?.toString() ?? '0') ?? 0;

      return Restaurant(
        name: item['name'] ?? '정보 없음',
        category: item['category'] ?? '식당',
        region: item['region'] ?? cityName,
        rating: rRating,
        reviews: rReviews,
        price: rPrice,
        address: item['region'] ?? '',
        lat: rLat,
        lng: rLng,
        isOpen: true,
        opentime: item['opentime'] ?? '',
        tips: item['tips'] ?? '',
        waiting: item['waiting'] ?? '대기 정보 없음',
        link: '',
        image: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=400',
        distance: Geolocator.distanceBetween(lat, lng, rLat, rLng),
      );
    }).toList();
  }
}