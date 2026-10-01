import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder_item.dart';
import '../models/note_item.dart';

class StorageService {
  static const String _remindersKey = 'saved_reminders_v1';
  static const String _notesKey = 'saved_notes_v1';
  static const String _apiKey = 'gemini_api_key';
  static const String _backendUrlKey = 'custom_backend_url';
  static const String _preferredModeKey = 'preferred_mode';

  static Future<List<ReminderItem>> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_remindersKey) ?? [];
    return jsonList
        .map((e) => ReminderItem.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  static Future<void> saveReminders(List<ReminderItem> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = reminders.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_remindersKey, jsonList);
  }

  static Future<List<NoteItem>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_notesKey) ?? [];
    return jsonList
        .map((e) => NoteItem.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> saveNotes(List<NoteItem> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = notes.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_notesKey, jsonList);
  }

  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKey) ?? '';
  }

  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKey, key.trim());
  }

  static Future<String> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backendUrlKey) ?? '';
  }

  static Future<void> setBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendUrlKey, url.trim());
  }

  static Future<String> getPreferredMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_preferredModeKey) ?? 'auto';
  }

  static Future<void> setPreferredMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredModeKey, mode);
  }
}
