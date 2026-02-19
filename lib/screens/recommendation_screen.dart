import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _sortBy = 'rating'; // 정렬 상태: rating, distance

  @override
  void initState() {
    super.initState();
    _fetchAndLoad();
  }

  // 3. [에러 핸들링 및 오프라인 모드] 로직 통합
  Future<void> _fetchAndLoad() async {
    setState(() => _isLoading = true);
    try {
      Position pos = await Geolocator.getCurrentPosition();
      final results = await GeminiService.fetchRecommendations(
        lat: pos.latitude, lng: pos.longitude, apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
      );

      // 성공 시 최신 데이터 캐싱
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_recommendations', jsonEncode(results.map((e) => e.toJson()).toList()));

      setState(() {
        _allRestaurants = results;
        _applySort();
        _isLoading = false;
      });
    } catch (e) {
      // 에러 발생 시 캐시 데이터 로드
      _loadOfflineData();
    }
  }

  void _loadOfflineData() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_recommendations');
    if (cached != null) {
      Iterable l = jsonDecode(cached);
      setState(() {
        _allRestaurants = List<Restaurant>.from(l.map((model) => Restaurant.fromJson(model)));
        _applySort();
        _isLoading = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오프라인 모드: 이전 추천 결과를 표시합니다.')));
    } else {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('데이터를 불러올 수 없습니다.')));
    }
  }

  // 4. [필터링 및 정렬] 로직 구현
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
          // 2. [지도 보기] 및 [정렬] 메뉴 버튼 추가
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              // MapViewScreen으로 이동 로직 (구현 필요)
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('준비 중인 기능입니다.')));
            },
          ),
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
                RestaurantCard(restaurant: res),
                Positioned(right: 10, top: 10, child: IconButton(
                  icon: const Icon(Icons.bookmark_add, color: Colors.blue, size: 32),
                  onPressed: () => _save(res),
                )),
              ],
            );
          },
        ),
      ),
    );
  }
}