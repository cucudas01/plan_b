import 'package:geolocator/geolocator.dart';

class Restaurant {
  final String name;
  final String? nameLocal;
  final String category;
  final String region;
  final double rating;
  final int reviews;
  final int price;
  final String address;
  final double lat;
  final double lng;
  final bool isOpen;
  final String opentime;
  final String tips;
  final String waiting; // AI의 상세 대기 예측 정보 포함
  final String link;
  final String? image;
  double? distance;

  Restaurant({
    required this.name, this.nameLocal, required this.category, required this.region,
    required this.rating, required this.reviews, required this.price, required this.address,
    required this.lat, required this.lng, required this.isOpen, required this.opentime,
    required this.tips, required this.waiting, required this.link, this.image, this.distance,
  });

  // 기기 저장을 위한 JSON 변환 (오프라인 모드 및 저장 기능용)
  Map<String, dynamic> toJson() => {
    'name': name, 'name_local': nameLocal, 'category': category, 'region': region,
    'rating': rating, 'reviews': reviews, 'price': price, 'address': address,
    'lat': lat, 'lng': lng, 'is_open': isOpen, 'opentime': opentime,
    'tips': tips, 'waiting': waiting, 'link': link, 'image': image,
    'distance': distance,
  };

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
    name: json['name'], nameLocal: json['name_local'], category: json['category'],
    region: json['region'], rating: (json['rating'] ?? 0.0).toDouble(), reviews: json['reviews'] ?? 0,
    price: json['price'] ?? 0, address: json['address'] ?? '', lat: json['lat'], lng: json['lng'],
    isOpen: json['is_open'] ?? true, opentime: json['opentime'] ?? '',
    tips: json['tips'] ?? '', waiting: json['waiting'] ?? '', link: json['link'] ?? '',
    image: json['image'], distance: json['distance']?.toDouble(),
  );

  // Google Places API 데이터 변환 연동
  factory Restaurant.fromPlaces(Map<String, dynamic> json, double cLat, double cLng) {
    final rLat = json['geometry']['location']['lat']?.toDouble() ?? 0.0;
    final rLng = json['geometry']['location']['lng']?.toDouble() ?? 0.0;
    return Restaurant(
      name: json['name'] ?? '정보 없음', category: (json['types'] as List?)?.first ?? '식당',
      region: json['vicinity'] ?? '주변', rating: (json['rating'] ?? 0.0).toDouble(),
      reviews: json['user_ratings_total'] ?? 0, price: 0, address: json['vicinity'] ?? '',
      lat: rLat, lng: rLng, isOpen: json['opening_hours']?['open_now'] ?? false,
      opentime: '정보없음', tips: '', waiting: '실시간 정보 확인 필요', link: '',
      image: json['photos'] != null ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${json['photos'][0]['photo_reference']}' : null,
      distance: Geolocator.distanceBetween(cLat, cLng, rLat, rLng),
    );
  }
}