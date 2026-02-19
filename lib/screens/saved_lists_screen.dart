import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant.dart';
import 'recommendation_screen.dart';

class SavedListsScreen extends StatefulWidget {
  const SavedListsScreen({super.key});

  @override
  State<SavedListsScreen> createState() => _SavedListsScreenState();
}

class _SavedListsScreenState extends State<SavedListsScreen> {
  Map<String, List<Restaurant>> _groupedData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('saved_restaurants');
    if (data == null) return;

    List<Restaurant> all = (jsonDecode(data) as List).map((e) => Restaurant.fromJson(e)).toList();
    Map<String, List<Restaurant>> grouped = {};
    for (var res in all) {
      grouped.putIfAbsent(res.region, () => []).add(res);
    }
    setState(() => _groupedData = grouped);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan B: 내 맛집')),
      body: _groupedData.isEmpty
          ? const Center(child: Text('저장된 맛집이 없습니다.'))
          : ListView(
        children: _groupedData.keys.map((city) => ExpansionTile(
          title: Text('$city (${_groupedData[city]!.length})'),
          children: _groupedData[city]!.map((res) => ListTile(
            title: Text(res.name),
            subtitle: Text(res.category),
            trailing: const Icon(Icons.chevron_right),
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