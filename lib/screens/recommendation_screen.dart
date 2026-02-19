import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/restaurant.dart';
import '../services/gemini_service.dart';
import '../widgets/restaurant_card.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  List<Restaurant> _allRestaurants = [];
  List<Restaurant> _filteredRestaurants = [];
  bool _isLoading = true;
  String _sortBy = 'rating';

  @override
  void initState() {
    super.initState();
    _fetchAndLoad();
  }

  // 수정된 부분: 식당 이름과 지역명으로 구글 맵 검색 실행
  Future<void> _launchMaps(String name, String region) async {
    // 식당 이름과 지역을 합쳐서 검색 쿼리를 만듭니다.
    final query = Uri.encodeComponent('$name $region');
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지도를 열 수 없습니다.')),
        );
      }
    }
  }

  Future<void> _fetchAndLoad() async {
    setState(() => _isLoading = true);
    try {
      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('위치 서비스가 꺼져 있습니다.');

      // 위치 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('위치 권한이 거부되었습니다.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 영구적으로 거부되었습니다.');
      }

      Position pos = await Geolocator.getCurrentPosition();
      final results = await GeminiService.fetchRecommendations(
        lat: pos.latitude,
        lng: pos.longitude,
        apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_recommendations', jsonEncode(results.map((e) => e.toJson()).toList()));

      setState(() {
        _allRestaurants = results;
        _applySort();
        _isLoading = false;
      });
    } catch (e) {
      _loadOfflineData(e.toString());
    }
  }

  void _loadOfflineData([String? errorMsg]) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_recommendations');
    setState(() => _isLoading = false);
    if (cached != null) {
      Iterable l = jsonDecode(cached);
      setState(() {
        _allRestaurants = List<Restaurant>.from(l.map((model) => Restaurant.fromJson(model)));
        _applySort();
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오프라인 모드 데이터를 표시합니다.')));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg ?? '데이터를 불러올 수 없습니다.')));
    }
  }

  void _applySort() {
    setState(() {
      _filteredRestaurants = List.from(_allRestaurants);
      if (_sortBy == 'rating') {
        _filteredRestaurants.sort((a, b) => b.rating.compareTo(a.rating));
      } else if (_sortBy == 'distance') {
        _filteredRestaurants.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
      }
    });
  }

  Future<void> _save(Restaurant res) async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> list = jsonDecode(prefs.getString('saved_restaurants') ?? '[]');
    list.add(res.toJson());
    await prefs.setString('saved_restaurants', jsonEncode(list));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res.name} 저장됨!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 추천 결과'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              _sortBy = value;
              _applySort();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rating', child: Text('평점 높은 순')),
              const PopupMenuItem(value: 'distance', child: Text('가까운 순')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchAndLoad,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _filteredRestaurants.length,
          itemBuilder: (context, i) {
            final res = _filteredRestaurants[i];
            return Stack(
              children: [
                RestaurantCard(
                  restaurant: res,
                  onTap: () => _launchMaps(res.name, res.region), // 수정된 함수 호출
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: IconButton(
                    icon: const Icon(Icons.bookmark_add, color: Colors.blue, size: 32),
                    onPressed: () => _save(res),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}