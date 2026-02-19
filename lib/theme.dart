import 'package:flutter/material.dart';

class AppTheme {
  // 앱의 포인트 컬러 (블루)
  static const primaryColor = Color(0xFF2563EB);

  static final ThemeData theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      surface: Colors.white,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA), // 밝은 회색 배경
    fontFamily: 'Pretendard', // 깔끔한 폰트 설정
    appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.black87)),
  );
}