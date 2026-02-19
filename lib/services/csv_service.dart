import 'dart:io';
import 'package:csv/csv.dart';

class CsvService {
  Future<List<List<dynamic>>> loadCsvData(String filePath) async {
    final file = File(filePath);
    final csvString = await file.readAsString();
    return const CsvToListConverter().convert(csvString);
  }
}