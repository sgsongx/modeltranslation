import 'dart:convert';

import 'package:modeltranslation/core/domain/gateways/record_repository.dart';
import 'package:modeltranslation/core/domain/translation_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsRecordRepository implements RecordRepository {
  static const String _recordsKey = 'translation.records.v1';

  @override
  Future<void> save(TranslationRecord record) async {
    final records = await _loadRecords();
    records.removeWhere((existing) => existing.id == record.id);
    records.add(record);
    await _persistRecords(records);
  }

  @override
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recordsKey);
  }

  @override
  Future<void> deleteById(String id) async {
    final records = await _loadRecords();
    records.removeWhere((record) => record.id == id);
    await _persistRecords(records);
  }

  @override
  Future<TranslationRecord?> getById(String id) async {
    final records = await _loadRecords();
    for (final record in records) {
      if (record.id == id) {
        return record;
      }
    }

    return null;
  }

  @override
  Future<List<TranslationRecord>> listRecent({int limit = 50}) async {
    final sorted = await _loadRecords()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<TranslationRecord>> search(String query) async {
    final normalized = query.toLowerCase();
    final records = await _loadRecords();
    return records.where((record) {
      return record.sourceText.toLowerCase().contains(normalized) ||
          record.translatedText.toLowerCase().contains(normalized);
    }).toList();
  }

  Future<List<TranslationRecord>> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <TranslationRecord>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <TranslationRecord>[];
      }

      return decoded
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
          .map(_fromMap)
          .toList();
    } catch (_) {
      return <TranslationRecord>[];
    }
  }

  Future<void> _persistRecords(List<TranslationRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = records.map(_toMap).toList(growable: false);
    await prefs.setString(_recordsKey, jsonEncode(encoded));
  }

  Map<String, Object?> _toMap(TranslationRecord record) {
    return <String, Object?>{
      'id': record.id,
      'sourceText': record.sourceText,
      'translatedText': record.translatedText,
      'provider': record.provider,
      'model': record.model,
      'paramsJson': record.paramsJson,
      'status': record.status.name,
      'errorMessage': record.errorMessage,
      'createdAt': record.createdAt.toIso8601String(),
    };
  }

  TranslationRecord _fromMap(Map<String, dynamic> map) {
    return TranslationRecord(
      id: (map['id'] as String?) ?? '',
      sourceText: (map['sourceText'] as String?) ?? '',
      translatedText: (map['translatedText'] as String?) ?? '',
      provider: (map['provider'] as String?) ?? '',
      model: (map['model'] as String?) ?? '',
      paramsJson: (map['paramsJson'] as String?) ?? '{}',
      status: _statusFromName(map['status'] as String?),
      errorMessage: map['errorMessage'] as String?,
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  TranslationStatus _statusFromName(String? name) {
    for (final status in TranslationStatus.values) {
      if (status.name == name) {
        return status;
      }
    }
    return TranslationStatus.failure;
  }
}
