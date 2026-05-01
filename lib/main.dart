import 'package:flutter/material.dart';
import 'dart:io';
import 'db_helper.dart';
import 'note_form.dart'; 

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_linkify/flutter_linkify.dart';

import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  // Стартираме Splash Screen веднага, за да избегнем черния екран
  runApp(const MaterialApp(
    home: SplashScreen(),
    debugShowCheckedModeBanner: false,
  ));

  WidgetsFlutterBinding.ensureInitialized(); 

  // Инициализация на часови зони (void функция)
  tz.initializeTimeZones();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const BusinessOrganizerApp());
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Опитваме да заредим иконата, ако не успеем - показваме икона по подразбиране
            Image.asset('@mipmap/ic_launcher', width: 100, height: 100, errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.note_alt, size: 100, color: Colors.blue);
            }),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class BusinessOrganizerApp extends StatelessWidget {
  const BusinessOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My memo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, 
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isGridView = false;
  final dbHelper = DatabaseHelper();
  late StreamSubscription _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _refreshItems();
    _requestPermissions();

    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> files) {
      _processSharedData(files);
    });

    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        _processSharedData(files);
        ReceiveSharingIntent.instance.reset(); 
      }
    });
  }

  void _refreshItems() async {
    final data = await dbHelper.queryAllRows();
    setState(() {
      _items = data;
      _isLoading = false;
    });
  }

  void _requestPermissions() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _processSharedData(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final sharedFile = files.first;
    Map<String, dynamic> sharedItem = {};
    
    if (sharedFile.type == SharedMediaType.text || sharedFile.type == SharedMediaType.url) {
      sharedItem = {'title': "Споделен текст", 'content': sharedFile.path};
    } else {
      sharedItem = {'title': "Споделена снимка", 'imagePath': sharedFile.path};
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteFormScreen(item: sharedItem, onSaved: _refreshItems),
      ),
    );
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My memo'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: NoteSearchDelegate(items: _items, onRefresh: _refreshItems),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Няма записи.'))
              : _isGridView
                  ? MasonryGridView.count(
                      padding: const EdgeInsets.all(10),
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      itemCount: _items.length,
                      itemBuilder: (context, index) => _buildItemCard(_items[index], index),
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) => _buildItemCard(_items[index], index),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => NoteFormScreen(item: null, onSaved: _refreshItems)),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, int index) {
    return Dismissible(
      key: Key(item['id'].toString()),
      direction: _isGridView ? DismissDirection.none : DismissDirection.startToEnd,
      onDismissed: (direction) => _deleteItem(item, index),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NoteFormScreen(item: item, onSaved: _refreshItems)),
            );
          },
          child: _isGridView ? _buildGridCardContent(item) : _buildListCardContent(item),
        ),
      ),
    );
  }

  Widget _buildGridCardContent(Map<String, dynamic> item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item['imagePath'] != null)
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            width: double.infinity,
            color: Colors.grey[200],
            child: Image.file(File(item['imagePath']), fit: BoxFit.contain),
          ),
        _buildTextInfo(item, isGrid: true),
      ],
    );
  }

  Widget _buildListCardContent(Map<String, dynamic> item) {
    if (item['imagePath'] == null) return _buildTextInfo(item, isGrid: false);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 1,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 180),
              color: Colors.grey[100],
              child: Image.file(File(item['imagePath']), fit: BoxFit.contain),
            ),
          ),
          Expanded(flex: 2, child: _buildTextInfo(item, isGrid: false)),
        ],
      ),
    );
  }

  Widget _buildTextInfo(Map<String, dynamic> item, {required bool isGrid}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((item['title'] ?? "").isNotEmpty)
                  Text(
                    item['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if ((item['title'] ?? "").isNotEmpty) const SizedBox(height: 4),
                // Важно: Използваме SelectableLinkify или GestureDetector, за да не се крадат жестовете
                GestureDetector(
                  onTap: () {}, // Празен тап, за да спрем bubbling-а към InkWell при клик върху линк
                  child: Linkify(
                    text: item['content'] ?? "",
                    onOpen: (link) async {
                      final url = Uri.parse(link.url);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                    maxLines: isGrid ? 6 : 4,
                    overflow: TextOverflow.ellipsis,
                    linkStyle: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: item['isCompleted'] == 1,
              onChanged: (val) => _toggleComplete(item, val),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(Map<String, dynamic> item, int index) async {
    final id = item['id'];
    setState(() => _items.removeAt(index));
    await dbHelper.deleteItem(id);
    _refreshItems();
  }

  Future<void> _toggleComplete(Map<String, dynamic> item, bool? isChecked) async {
    if (isChecked == null) return;
    await dbHelper.updateItem({...item, 'isCompleted': isChecked ? 1 : 0});
    _refreshItems();
  }
}

// Помощни класове за търсене и т.н.
class NoteSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> items;
  final VoidCallback onRefresh; 
  NoteSearchDelegate({required this.items, required this.onRefresh});

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildResults(context);
  @override
  Widget buildSuggestions(BuildContext context) => _buildResults(context);

  Widget _buildResults(BuildContext context) {
    final results = items.where((i) => 
      i['title'].toString().toLowerCase().contains(query.toLowerCase()) ||
      i['content'].toString().toLowerCase().contains(query.toLowerCase())
    ).toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) => ListTile(
        title: Text(results[index]['title']),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => NoteFormScreen(item: results[index], onSaved: onRefresh)));
        },
      ),
    );
  }
}

// Future<void> _scheduleNotification(int id, String title, String body, DateTime scheduledDate) async {
//   try {
//     print("Стъпка 1: Извиквам планиране за $scheduledDate");
//     await flutterLocalNotificationsPlugin.zonedSchedule(
//       id,
//       title,
//       body,
//       tz.TZDateTime.from(scheduledDate, tz.local),
//       const NotificationDetails(
//         android: AndroidNotificationDetails(
//           'reminder_channel',
//           'Напомняния',
//           importance: Importance.max,
//           priority: Priority.high,
//         ),
//       ),
//       androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
//       uiLocalNotificationDateInterpretation:
//           UILocalNotificationDateInterpretation.absoluteTime,
//     );
//     print("Стъпка 2: Планирането приключи успешно!"); // Ако видиш това, значи работи
//   } catch (e) {
//     // ТУК ЩЕ ВИДИШ ИСТИНСКАТА ГРЕШКА В КОНЗОЛАТА
//     print("ГРЕШКА ПРИ ПЛАНИРАНЕ: $e");
//   }
// }

// Future<void> _scheduleNotification(int id, String title, String body, DateTime scheduledDate) async {
//   // Проверка дали времето не е в миналото
//   if (scheduledDate.isBefore(DateTime.now())) {
//     print("Грешка: Избраното време е в миналото!");
//     return;
//   }
//   await flutterLocalNotificationsPlugin.zonedSchedule(
//     id,
//     title,
//     body,
//     tz.TZDateTime.from(scheduledDate, tz.local),
//     const NotificationDetails(
//       android: AndroidNotificationDetails(
//         'reminders_channel',
//         'Напомняния',
//         importance: Importance.max,
//         priority: Priority.high,
//       ),
//     ),
//     androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
//     uiLocalNotificationDateInterpretation:
//         UILocalNotificationDateInterpretation.absoluteTime,
//   );
// }

  // void _showTextDetails(Map<String, dynamic> item) {
  //   final String content = item['content'] ?? "";
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text(item['title'] ?? "Детайли"),
  //       content: SingleChildScrollView(
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             SelectableLinkify(
  //               text: content,
  //               onOpen: (link) async {
  //                 final Uri url = Uri.parse(link.url);
  //                 if (await canLaunchUrl(url)) {
  //                   await launchUrl(url, mode: LaunchMode.externalApplication);
  //                 } else {
  //                   if (mounted) {
  //                     ScaffoldMessenger.of(context).showSnackBar(
  //                       const SnackBar(content: Text("Неуспешно отваряне на линка")),
  //                     );
  //                   }
  //                 }
  //               },
  //               style: const TextStyle(fontSize: 16),
  //               linkStyle: const TextStyle(
  //                 color: Colors.blue,
  //                 fontWeight: FontWeight.bold,
  //                 decoration: TextDecoration.underline,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text("Затвори"),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Функция за избор на Дата и Час
  // Future<void> _pickDateTime(BuildContext context) async {
  //   // 1. Избор на дата
  //   final DateTime? date = await showDatePicker(
  //     context: context,
  //     initialDate: DateTime.now(),
  //     firstDate: DateTime.now(),
  //     lastDate: DateTime(2030),
  //     helpText: 'Избери дата за напомняне',
  //   );
  //   if (date != null) {
  //     // 2. Избор на час
  //     final TimeOfDay? time = await showTimePicker(
  //       context: context,
  //       initialTime: TimeOfDay.now(),
  //       helpText: 'Избери час',
  //     );
  //     if (time != null) {
  //       setState(() {
  //         selectedDateTime = DateTime(
  //           date.year,
  //           date.month,
  //           date.day,
  //           time.hour,
  //           time.minute,
  //         );
  //       });
  //     }
  //   }
  // }

  // Widget _buildItemCard(Map<String, dynamic> item, int index) {
  //   return Dismissible(
  //     key: Key(item['id'].toString()),
  //     direction: DismissDirection.startToEnd,
  //     background: Container(
  //       color: Colors.red,
  //       alignment: Alignment.centerLeft,
  //       padding: const EdgeInsets.symmetric(horizontal: 20),
  //       child: const Icon(Icons.delete, color: Colors.white),
  //     ),
  //     onDismissed: (direction) => _deleteItem(item, index), // Изнеси логиката за триене тук
  //     child: Card(
  //       elevation: 2,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //       child: InkWell( // За по-добър ефект при натискане
  //         onTap: () => item['imagePath'] != null 
  //             ? _openImage(item) 
  //             : _showTextDetails(item),
  //         onLongPress: () => _showAddForm(context, item: item),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             if (item['imagePath'] != null)
  //               ClipRRect(
  //                 borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
  //                 child: Image.file(
  //                   File(item['imagePath']),
  //                   fit: BoxFit.cover,
  //                   width: double.infinity,
  //                   // Тук височината ще се адаптира сама, ако не я ограничиш
  //                 ),
  //               ),
  //             Padding(
  //               padding: const EdgeInsets.all(12),
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(
  //                     item['title'],
  //                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
  //                     maxLines: 2,
  //                     overflow: TextOverflow.ellipsis,
  //                   ),
  //                   const SizedBox(height: 8),
  //                   Text(
  //                     item['content'],
  //                     maxLines: _isGridView ? 5 : _maxRows, // В Grid показвай по-малко
  //                     overflow: TextOverflow.ellipsis,
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             // Малък ред с Checkbox отдолу
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.end,
  //               children: [
  //                 Checkbox(
  //                   value: item['isCompleted'] == 1,
  //                   onChanged: (val) => _toggleComplete(item, val),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     builder: (BuildContext context) {
  //       return StatefulBuilder( // Използваме StatefulBuilder, за да работи Switch и датата вътре в панела
  //         builder: (BuildContext context, StateSetter setModalState) {
  //           return Padding(
  //             padding: EdgeInsets.only(
  //               bottom: MediaQuery.of(context).viewInsets.bottom,
  //               left: 10, right: 10, top: 10,
  //             ),
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 Text(
  //                   item == null ? 'Нов запис' : 'Редактиране', 
  //                   style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
  //                 ),
  //                 TextField(
  //                   controller: _titleController,
  //                   decoration: const InputDecoration(labelText: 'Заглавие'),
  //                 ),
  //                 TextField(
  //                   controller: _contentController,
  //                   decoration: const InputDecoration(labelText: 'Описание / Бележка'),
  //                   maxLines: 3,
  //                 ),
  //                 const SizedBox(height: 20),
  //                 Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceAround,
  //                   children: [
  //                     TextButton.icon(
  //                       onPressed: () async {
  //                         // Извикваме оригиналната функция и обновяваме състоянието на панела
  //                         await _pickDateTime(context);
  //                         setModalState(() {}); 
  //                       },
  //                       icon: Icon(Icons.alarm, color: selectedDateTime != null ? Colors.green : Colors.blue),
  //                       label: Text(
  //                         selectedDateTime == null 
  //                           ? 'Напомняне' 
  //                           : '${selectedDateTime!.day}.${selectedDateTime!.month.toString().padLeft(2, '0')} в ${selectedDateTime!.hour}:${selectedDateTime!.minute.toString().padLeft(2, '0')}',
  //                         style: TextStyle(color: selectedDateTime != null ? Colors.green : Colors.blue),
  //                       ),
  //                     ),
  //                     ElevatedButton(
  //                       onPressed: () async {
  //                         String? finalPath = item?['imagePath']; // Запазваме стария път по подразбиране
  //                         // Логика за снимката (само ако е променена или е нова)
  //                         if (_selectedImage != null && _selectedImage!.path != item?['imagePath']) {
  //                           if (_shouldCopyImage) {
  //                             finalPath = await FileService.saveImageLocally(_selectedImage!);
  //                           } else {
  //                             finalPath = _selectedImage!.path;
  //                           }
  //                         }
  //                         Map<String, dynamic> data = {
  //                           'title': _titleController.text,
  //                           'content': _contentController.text,
  //                           'imagePath': finalPath,
  //                           'isLocalCopy': _shouldCopyImage ? 1 : 0,
  //                           'reminderDate': selectedDateTime?.toIso8601String(),
  //                           'isCompleted': item != null ? item['isCompleted'] : 0,
  //                         };
  //                         // 1. Първо записваме/обновяваме в базата данни
  //                         int savedId; // Променлива, в която ще пазим ID-то за алармата
  //                         if (item == null) {
  //                           // При нов запис insertItem обикновено връща ID-то на новия ред
  //                           savedId = await dbHelper.insertItem(data);
  //                         } else {
  //                           data['id'] = item['id']; // Добавяме ID за ъпдейта
  //                           await dbHelper.updateItem(data);
  //                           savedId = item['id']; // Вече имаме ID-то от съществуващия елемент
  //                         }
  //                         // 2. СЛЕД като сме сигурни, че данните са в базата, планираме известието
  //                         print("selectedDateTime е: $selectedDateTime с ID: $savedId");
  //                         if (selectedDateTime != null) {
  //                             await _scheduleNotification(
  //                             savedId, // Уникалното ID на бележката
  //                             _titleController.text.isEmpty ? "Напомняне" : _titleController.text,
  //                             _contentController.text,
  //                             selectedDateTime!,
  //                             // ТЕСТОВ КОД (сложи го на мястото на _scheduleNotification за проба)
  //                             // await flutterLocalNotificationsPlugin.show(
  //                             //   999,
  //                             //   "Тест",
  //                             //   "Ако виждаш това, известията работят!",
  //                             //   const NotificationDetails(
  //                             //     android: AndroidNotificationDetails('test_channel', 'Test'),
  //                             //   ),
  //                           );
  //                           print("Напомнянето е настроено за: $selectedDateTime с ID: $savedId");
  //                         } else if (item != null) {
  //                           // Ако редактираме и потребителят е премахнал датата, 
  //                           // е добра идея да изтрием старото известие
  //                           await flutterLocalNotificationsPlugin.cancel(savedId);
  //                         }
  //                         // Изчистване и затваряне
  //                         _titleController.clear();
  //                         _contentController.clear();
  //                         _selectedImage = null;
  //                         selectedDateTime = null;
  //                         _refreshItems();
  //                         Navigator.pop(context);
  //                       },
  //                       child: Text(item == null ? 'Запази' : 'Обнови'),
  //                     ),
  //                   ],
  //                 ),
  //                 const SizedBox(height: 20), // Увери се, че тук има запетая
  //                 Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                   children: [
  //                     const Row(
  //                       children: [
  //                         Icon(Icons.storage, color: Colors.grey),
  //                         SizedBox(width: 12),
  //                         Text(
  //                           "Копирай локално",
  //                           style: TextStyle(fontSize: 16),
  //                         ),
  //                       ],
  //                     ),
  //                     Switch(
  //                       value: _shouldCopyImage,
  //                       onChanged: (bool value) {
  //                         // Провери дали тези функции са достъпни тук
  //                         setState(() => _shouldCopyImage = value);
  //                         setModalState(() => _shouldCopyImage = value);
  //                       },
  //                     ),
  //                   ],
  //                 ),
  //               ],
  //             ),
  //           );
  //         }
  //       );
  //     },
  //   );

