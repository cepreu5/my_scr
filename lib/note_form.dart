import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'db_helper.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class NoteFormScreen extends StatefulWidget {
  final Map<String, dynamic>? item;
  final VoidCallback onSaved;

  const NoteFormScreen({super.key, this.item, required this.onSaved});

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _imagePath;
  DateTime? _reminderTime;
  Color _selectedColor = Colors.white;
  final dbHelper = DatabaseHelper();
  
  bool _isEditing = false;

  final List<Color> _noteColors = [
    Colors.white,
    const Color(0xFFFFF9C4), // Светло жълто
    const Color(0xFFFFCCBC), // Светло оранжево
    const Color(0xFFC8E6C9), // Светло зелено
    const Color(0xFFB3E5FC), // Светло синьо
    const Color(0xFFF8BBD0), // Светло розово
    const Color(0xFFE1BEE7), // Светло лилаво
  ];

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _titleController.text = widget.item!['title']?.toString() ?? "";
      _contentController.text = widget.item!['content']?.toString() ?? "";
      _imagePath = widget.item!['imagePath'];
      
      if (widget.item!['reminderTime'] != null) {
        try {
          _reminderTime = DateTime.parse(widget.item!['reminderTime']);
        } catch (e) {
          debugPrint("Грешка при дата: $e");
        }
      }

      if (widget.item!['color'] != null) {
        _selectedColor = Color(widget.item!['color']);
      } else {
        _selectedColor = Colors.white;
      }

      _isEditing = widget.item!['id'] == null;
    } else {
      _isEditing = true;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => _imagePath = pickedFile.path);
      }
    } catch (e) {
      debugPrint("Грешка камера: $e");
    }
  }

  // Функция за избор на дата и час
  Future<void> _pickReminderTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _reminderTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      helpText: 'Избери дата за напомняне',
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _reminderTime != null 
            ? TimeOfDay.fromDateTime(_reminderTime!) 
            : TimeOfDay.now(),
        helpText: 'Избери час за напомняне',
      );

      if (pickedTime != null) {
        setState(() {
          _reminderTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _save() async {
    final Map<String, dynamic> data = {
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'imagePath': _imagePath,
      'reminderTime': _reminderTime?.toIso8601String(),
      'color': _selectedColor.value,
      'isCompleted': widget.item?['isCompleted'] ?? 0,
    };

    try {
      if (widget.item == null || widget.item!['id'] == null) {
        await dbHelper.insertItem(data);
      } else {
        data['id'] = widget.item!['id'];
        await dbHelper.updateItem(data);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Грешка при запис: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openFullScreenImage() {
    if (_imagePath == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImage(
          imagePath: _imagePath!,
          title: _titleController.text.isEmpty ? "Преглед" : _titleController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String reminderText = 'Напомняне';
    if (_reminderTime != null) {
      reminderText = '${_reminderTime!.day}.${_reminderTime!.month} ${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      backgroundColor: _selectedColor,
      appBar: AppBar(
        backgroundColor: _selectedColor,
        elevation: 0,
        title: Text(_isEditing ? (widget.item?['id'] == null ? 'Нова бележка' : 'Редактиране') : 'Преглед'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.save), 
              onPressed: _save,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_imagePath != null)
                    GestureDetector(
                      onTap: _isEditing ? null : _openFullScreenImage,
                      child: Stack(
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxHeight: 400),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.black12,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(File(_imagePath!), fit: BoxFit.contain),
                            ),
                          ),
                          if (!_isEditing)
                            const Positioned(
                              right: 8,
                              bottom: 8,
                              child: Icon(Icons.fullscreen, color: Colors.black54, size: 30),
                            ),
                          if (_isEditing)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                  onPressed: () => setState(() => _imagePath = null),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_isEditing)
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(hintText: 'Заглавие', border: InputBorder.none),
                    )
                  else if (_titleController.text.isNotEmpty)
                    Text(_titleController.text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_isEditing)
                    TextField(
                      controller: _contentController,
                      maxLines: null,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(hintText: 'Съдържание...', border: InputBorder.none),
                    )
                  else
                    Linkify(
                      text: _contentController.text,
                      onOpen: (link) async {
                        final url = Uri.parse(link.url);
                        if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                      },
                      style: const TextStyle(fontSize: 18),
                      linkStyle: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                    ),
                ],
              ),
            ),
          ),
          if (_isEditing) _buildBottomTools(reminderText),
        ],
      ),
    );
  }

  Widget _buildBottomTools(String reminderText) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        border: const Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _noteColors.map((color) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor == color ? Colors.blue : Colors.black26,
                        width: _selectedColor == color ? 2 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.camera_alt), onPressed: _pickImage),
              const Spacer(),
              TextButton.icon(
                onPressed: _pickReminderTime,
                icon: const Icon(Icons.alarm),
                label: Text(reminderText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imagePath;
  final String title;
  const FullScreenImage({super.key, required this.imagePath, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(title)),
      body: Center(
        child: InteractiveViewer(child: Image.file(File(imagePath), fit: BoxFit.contain)),
      ),
    );
  }
}