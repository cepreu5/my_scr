import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'note_form.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
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
State createState() => _MainListScreenState();
}

class _MainListScreenState extends State {
final dbHelper = DatabaseHelper();
List<Map<String, dynamic>> _items = [];
late StreamSubscription _intentDataStreamSubscription;

@override
void initState() {
super.initState();
_refreshItems();

// Слушател за споделяне (медия/текст), докато приложението е отворено
_intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
  if (value.isNotEmpty) {
    _handleSharedMedia(value);
  }
}, onError: (err) {
  debugPrint("Грешка при поток на споделяне: \$err");
});

// В новите версии всичко (включително текст) се взима чрез getInitialMedia
ReceiveSharingIntent.instance.getInitialMedia().then((value) {
  if (value.isNotEmpty) {
    _handleSharedMedia(value);
  }
});
}

@override
void dispose() {
_intentDataStreamSubscription.cancel();
super.dispose();
}

// Универсална обработка на споделено съдържание
void _handleSharedMedia(List media) {
final sharedFile = media.first;

// В новите версии текстът се намира в sharedFile.value или .path в зависимост от типа
if (sharedFile.type == SharedMediaType.text || sharedFile.type == SharedMediaType.url) {
  final textContent = sharedFile.value ?? sharedFile.path;
  _handleSharedText(textContent);
} else {
  // Това е изображение или файл
  _openNoteForm(initialData: {
    'imagePath': sharedFile.path,
    'title': 'Споделено изображение',
    'content': '',
    'id': null,
    'color': Colors.white.value,
  });
}
}

void _handleSharedText(String text) {
if (text.isEmpty) return;
_openNoteForm(initialData: {
'content': text,
'title': 'Споделен текст',
'id': null,
'color': Colors.white.value,
});
}

Future _refreshItems() async {
final data = await dbHelper.queryAllRows();
setState(() {
_items = data;
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

Future _deleteItem(int id) async {
await dbHelper.deleteItem(id);
_refreshItems();
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('Бизнес Органайзер'),
centerTitle: true,
),
body: _items.isEmpty
? const Center(child: Text('Няма записи.'))
: ListView.builder(
padding: const EdgeInsets.all(8),
itemCount: _items.length,
itemBuilder: (context, index) {
final item = _items[index];
final Color cardColor = item['color'] != null
? Color(item['color'])
: Colors.white;

            return Card(
              color: cardColor,
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                onTap: () => _openNoteForm(initialData: item),
                leading: item['imagePath'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(item['imagePath']),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.note_alt_outlined, size: 30),
                title: Text(
                  item['title'] ?? 'Без заглавие',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['content'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item['reminderTime'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.alarm, size: 14, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateTime(item['reminderTime']),
                              style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.black45),
                  onPressed: () => _showDeleteDialog(item['id']),
                ),
              ),
            );
          },
        ),
  floatingActionButton: FloatingActionButton(
    onPressed: () => _openNoteForm(),
    child: const Icon(Icons.add),
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

void _showDeleteDialog(int id) {
showDialog(
context: context,
builder: (context) => AlertDialog(
title: const Text('Изтриване'),
content: const Text('Изтриване на бележката?'),
actions: [
TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отказ')),
TextButton(
onPressed: () {
_deleteItem(id);
Navigator.pop(context);
},
child: const Text('Изтрий', style: TextStyle(color: Colors.red)),
),
],
),
);
}
}