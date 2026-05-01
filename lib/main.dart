import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'note_form.dart';
import 'settings_screen.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';

void main() {
  runApp(const BusinessOrganizerApp());
}

class BusinessOrganizerApp extends StatelessWidget {
  const BusinessOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Бизнес Органайзер',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainListScreen(),
    );
  }
}

class MainListScreen extends StatefulWidget {
  const MainListScreen({super.key});

  @override
  State<MainListScreen> createState() => _MainListScreenState();
}

class _MainListScreenState extends State<MainListScreen> {
  final dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isGridView = false;
  int _appBackgroundColor = Colors.white.value;
  final TextEditingController _searchController = TextEditingController();
  late StreamSubscription _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshItems();

    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) _handleSharedMedia(value);
    }, onError: (err) => debugPrint("Грешка: $err"));

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) _handleSharedMedia(value);
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appBackgroundColor = prefs.getInt('bg_color') ?? Colors.white.value;
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSharedMedia(List<SharedMediaFile> media) {
    final sharedFile = media.first;
    if (sharedFile.type == SharedMediaType.text || sharedFile.type == SharedMediaType.url) {
      _handleSharedText(sharedFile.path);
    } else {
      _openNoteForm(initialData: {
        'imagePath': sharedFile.path,
        'title': 'Споделено изображение',
        'content': '',
        'id': null,
        'color': null,
        'isCompleted': 0,
      });
    }
  }

  void _handleSharedText(String text) {
    if (text.isEmpty) return;
    _openNoteForm(initialData: {
      'content': text,
      'title': 'Споделен текст',
      'id': null,
      'color': null,
      'isCompleted': 0,
    });
  }

  Future<void> _refreshItems() async {
    final data = await dbHelper.queryAllRows();
    setState(() {
      _allItems = data;
      _filterItems(_searchController.text);
    });
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = _allItems.where((item) {
        final title = (item['title'] ?? '').toLowerCase();
        final content = (item['content'] ?? '').toLowerCase();
        return title.contains(query.toLowerCase()) || content.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _openNoteForm({Map<String, dynamic>? initialData}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteFormScreen(
          item: initialData,
          onSaved: _refreshItems,
        ),
      ),
    );
  }

  Future<void> _toggleComplete(Map<String, dynamic> item) async {
    final newStatus = item['isCompleted'] == 1 ? 0 : 1;
    await dbHelper.updateItem({
      ...item,
      'isCompleted': newStatus,
    });
    _refreshItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(_appBackgroundColor),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Color(_appBackgroundColor).withOpacity(0.9),
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: TextField(
            controller: _searchController,
            onChanged: _filterItems,
            decoration: InputDecoration(
              hintText: 'Търсене...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.black.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              _loadSettings();
            },
          ),
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: _filteredItems.isEmpty
          ? const Center(child: Text('Няма открити бележки.'))
          : _isGridView ? _buildGrid() : _buildList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNoteForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) => _buildNoteCard(_filteredItems[index], false),
    );
  }

  // Обновен матричен изглед без "дупки" (Masonry-like)
  Widget _buildGrid() {
    // Разделяме елементите на две колони
    List<Map<String, dynamic>> leftColumn = [];
    List<Map<String, dynamic>> rightColumn = [];

    for (int i = 0; i < _filteredItems.length; i++) {
      if (i % 2 == 0) {
        leftColumn.add(_filteredItems[i]);
      } else {
        rightColumn.add(_filteredItems[i]);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: leftColumn.map((item) => _buildNoteCard(item, true)).toList(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: rightColumn.map((item) => _buildNoteCard(item, true)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> item, bool isGrid) {
    final bool isDone = item['isCompleted'] == 1;
    final Color cardColor = item['color'] != null ? Color(item['color']) : Colors.white;

    Widget content = Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isDone,
                  onChanged: (_) => _toggleComplete(item),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item['title'] ?? 'Без заглавие',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item['content'] ?? '',
            // Премахваме фиксирания брой редове в грид, за да се разтягат естествено
            maxLines: isGrid ? 5 : 5, 
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87,
              decoration: isDone ? TextDecoration.lineThrough : null,
            ),
          ),
          if (item['reminderTime'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, size: 14, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatDateTime(item['reminderTime']),
                      style: const TextStyle(
                        fontSize: 10, 
                        color: Colors.redAccent, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (!isGrid && item['imagePath'] != null) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100, maxHeight: 100),
                child: Image.file(File(item['imagePath']), fit: BoxFit.cover),
              ),
            ),
          ),
          Expanded(child: content),
        ],
      );
    } else if (isGrid && item['imagePath'] != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Image.file(File(item['imagePath']), fit: BoxFit.cover, width: double.infinity),
          ),
          content,
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Dismissible(
        key: Key(item['id'].toString()),
        direction: DismissDirection.startToEnd,
        background: Container(
          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (direction) async {
          await dbHelper.deleteItem(item['id']);
          _refreshItems();
        },
        child: Card(
          margin: EdgeInsets.zero,
          color: cardColor,
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _openNoteForm(initialData: item),
            child: content,
          ),
        ),
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return '';
    }
  }
}