import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _appBgColor = Colors.white.toARGB32();
  int _defaultNoteColor = Colors.white.toARGB32();

  final List<Color> _availableColors = [
    Colors.white,
    const Color(0xFFF5F5F5), // Светло сиво
    const Color(0xFFFFF9C4), // Светло жълто
    const Color(0xFFFFCCBC), // Светло оранжево
    const Color(0xFFC8E6C9), // Светло зелено
    const Color(0xFFB3E5FC), // Светло синьо
    const Color(0xFFF8BBD0), // Светло розово
    const Color(0xFFE1BEE7), // Светло лилаво
    const Color(0xFFD7CCC8), // Светло кафяво
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appBgColor = prefs.getInt('bg_color') ?? Colors.white.toARGB32();
      _defaultNoteColor = prefs.getInt('default_note_color') ?? Colors.white.toARGB32();
    });
  }

  Future<void> _saveSetting(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Фон на приложението'),
          const SizedBox(height: 10),
          _buildColorPicker(
            selectedColor: _appBgColor,
            onColorSelected: (color) => _saveSetting('bg_color', color.toARGB32()),
          ),
          const Divider(height: 40),
          _buildSectionTitle('Цвят на бележките по подразбиране'),
          const SizedBox(height: 10),
          _buildColorPicker(
            selectedColor: _defaultNoteColor,
            onColorSelected: (color) => _saveSetting('default_note_color', color.toARGB32()),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
    );
  }

  Widget _buildColorPicker({required int selectedColor, required Function(Color) onColorSelected}) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _availableColors.map((color) {
        bool isSelected = selectedColor == color.toARGB32();
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.black12,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8)] : null,
            ),
            child: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
          ),
        );
      }).toList(),
    );
  }
}