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
  String _priceFilter = 'all'; // [기능 1] 가격 필터 상태 변수

  @override
  void initState() {
    super.initState();
    _fetchAndLoad();
  }

  Future<void> _launchMaps(String name, String region) async {
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

  // [기능 5] 캐시 유효성 검사 및 데이터 로드
  Future<void> _fetchAndLoad() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();

      // 마지막 호출 시간 확인 (1시간 기준 캐싱)
      final lastFetchStr = prefs.getString('last_fetch_time');
      if (lastFetchStr != null) {
        final lastFetch = DateTime.parse(lastFetchStr);
        if (DateTime.now().difference(lastFetch).inHours < 1) {
          _loadOfflineData('최근 1시간 이내의 데이터를 불러왔습니다.');
          return;
        }
      }

      // 위치 권한 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('위치 서비스가 꺼져 있습니다.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('위치 권한이 거부되었습니다.');
      }

      Position pos = await Geolocator.getCurrentPosition();
      final results = await GeminiService.fetchRecommendations(
        lat: pos.latitude,
        lng: pos.longitude,
        apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
      );

      // 데이터 및 시간 캐싱
      await prefs.setString('cached_recommendations', jsonEncode(results.map((e) => e.toJson()).toList()));
      await prefs.setString('last_fetch_time', DateTime.now().toIso8601String());

      setState(() {
        _allRestaurants = results;
        _applySort();
        _isLoading = false;
      });
    } catch (e) {
      _loadOfflineData(e.toString());
    }
  }

  void _loadOfflineData([String? message]) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_recommendations');
    setState(() => _isLoading = false);
    if (cached != null) {
      Iterable l = jsonDecode(cached);
      setState(() {
        _allRestaurants = List<Restaurant>.from(l.map((model) => Restaurant.fromJson(model)));
        _applySort();
      });
      if (mounted && message != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('데이터를 불러올 수 없습니다.')));
    }
  }

  // [기능 1] 가격대별 필터링 로직 통합
  void _applySort() {
    setState(() {
      _filteredRestaurants = _allRestaurants.where((res) {
        if (_priceFilter == 'all') return true;
        if (_priceFilter == 'cheap') return res.price <= 15000;
        if (_priceFilter == 'mid') return res.price > 15000 && res.price <= 35000;
        if (_priceFilter == 'expensive') return res.price > 35000;
        return true;
      }).toList();

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

  // [기능 1] 필터 칩 빌더
  Widget _buildFilterChips() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterChip('전체', 'all'),
          _filterChip('가성비(~1.5만)', 'cheap'),
          _filterChip('적당함(~3.5만)', 'mid'),
          _filterChip('고급(3.5만~)', 'expensive'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _priceFilter == value,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _priceFilter = value;
              _applySort();
            });
          }
        },
      ),
    );
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
      body: Column(
        children: [
          _buildFilterChips(), // 필터 UI 추가
          Expanded(
            child: _isLoading
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
                        onTap: () => _launchMaps(res.name, res.region),
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
          ),
        ],
      ),
    );
  }
}