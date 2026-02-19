import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/saved_lists_screen.dart';

void main() async {
  // 비동기 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // .env 파일 로드 (API 키 보안)
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("환경 변수 파일(.env)을 찾을 수 없습니다: $e");
  }

  // 앱 실행 (MyApp 클래스를 호출합니다)
  runApp(const MyApp());
}

// 테스트 코드가 찾는 'MyApp' 클래스입니다.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plan B',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue, // 'Plan B'의 메인 테마 컬러
      ),
      // 앱의 첫 화면: 저장된 맛집 목록
      home: const SavedListsScreen(),
    );
  }
}