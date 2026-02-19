import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/restaurant.dart';
import 'recommendation_screen.dart';

class SavedListsScreen extends StatefulWidget {
  const SavedListsScreen({super.key});

  @override
  State<SavedListsScreen> createState() => _SavedListsScreenState();
}

class _SavedListsScreenState extends State<SavedListsScreen> {
  Map<String, List<Restaurant>> _groupedData = {};
  List<Restaurant> _allSaved = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('saved_restaurants');
    if (data == null) {
      setState(() => _groupedData = {});
      return;
    }

    List<Restaurant> all = (jsonDecode(data) as List).map((e) => Restaurant.fromJson(e)).toList();
    _allSaved = all;

    Map<String, List<Restaurant>> grouped = {};
    for (var res in all) {
      grouped.putIfAbsent(res.region, () => []).add(res);
    }
    setState(() => _groupedData = grouped);
  }

  // 식당 삭제 기능 (관리 기능)
  Future<void> _deleteRestaurant(String name) async {
    _allSaved.removeWhere((item) => item.name == name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_restaurants', jsonEncode(_allSaved.map((e) => e.toJson()).toList()));
    _loadData();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name 삭제됨')));
  }

  // 수정된 부분: 저장된 목록에서도 이름+지역 검색으로 지도 실행
  Future<void> _launchMaps(String name, String region) async {
    final query = Uri.encodeComponent('$name $region');
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan B: 내 맛집')),
      body: _groupedData.isEmpty
          ? const Center(child: Text('저장된 맛집이 없습니다.'))
          : ListView(
        children: _groupedData.keys.map((city) => ExpansionTile(
          title: Text('$city (${_groupedData[city]!.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: true,
          children: _groupedData[city]!.map((res) => ListTile(
            title: Text(res.name),
            subtitle: Text(res.category),
            leading: const Icon(Icons.restaurant_menu, color: Colors.blue),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteRestaurant(res.name),
            ),
            onTap: () => _launchMaps(res.name, res.region), // 목록 클릭 시 검색 실행
          )).toList(),
        )).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecommendationScreen())).then((_) => _loadData()),
        label: const Text('AI 맛집 추천'),
        icon: const Icon(Icons.auto_awesome),
      ),
    );
  }
}