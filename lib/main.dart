import 'package:flutter/material.dart';
import 'dart:io';
import 'db_helper.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_linkify/flutter_linkify.dart';

import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:photo_view/photo_view.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p; // добави и пакета 'path' за лесна работа с имена

void main() async {
  // Този ред гарантира, че Flutter е заредил всичко нужно, 
  // преди да се опиташ да отвориш базата данни или Intent-ите.
  WidgetsFlutterBinding.ensureInitialized(); 
  
  runApp(
    MaterialApp(
      home: const HomeScreen(), 
      theme: ThemeData(useMaterial3: true, primarySwatch: Colors.blue),
    ),
  );
}

bool _shouldCopyImage = true; // Стойност по подразбиране

class FileService {
  static Future<String> saveImageLocally(File image) async {
    try {
      // 1. Вземаме пътя до папката за документи на приложението
      final directory = await getApplicationDocumentsDirectory();
      // 2. Генерираме уникално име на файла (ползваме клеймо за време), 
      // за да не се презаписват снимките
      final String fileName = 'screenshot_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
      // 3. Създаваме пълния път за новия файл
      final String filePath = p.join(directory.path, fileName);
      // 4. Копираме файла на новото място
      final File localImage = await image.copy(filePath);
      return localImage.path; // Връщаме новия път, който ще запишем в SQLite
    } catch (e) {
      print("Грешка при запис на файл: $e");
      return image.path; // Ако нещо се обърка, връщаме оригиналния път като резервен вариант
    }
  }
}

class NoteSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> items;
  final Function(Map<String, dynamic>) onSelect;

  NoteSearchDelegate({required this.items, required this.onSelect});

  // Бутон за изчистване на текста
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  // Бутон за връщане назад
  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  // Резултати при търсене
  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  // Предложения, докато потребителят пише
  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final suggestions = items.where((item) {
      final title = item['title'].toLowerCase();
      final content = item['content'].toLowerCase();
      return title.contains(query.toLowerCase()) || content.contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        return ListTile(
          title: Text(item['title']),
          subtitle: Text(item['content'], maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            close(context, null);
            onSelect(item); // Изпълнява функцията за преглед
          },
        );
      },
    );
  }
}

class ImageDetailScreen extends StatelessWidget {
  final String imagePath;
  final String title;

  const ImageDetailScreen({super.key, required this.imagePath, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Черен фон за по-добър фокус върху снимката
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Hero(
          tag: imagePath, // Анимация за плавен преход
          child: PhotoView(
            imageProvider: FileImage(File(imagePath)),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.0,
          ),
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
      title: 'Бизнес органайзер',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // Използваме модерния дизайн на Google
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Примерен списък с данни (по-късно ще идват от базата данни)
  List<Map<String, dynamic>> _items = [];
  DateTime? selectedDateTime;
  bool _isLoading = true; // Индикатор за зареждане

  final dbHelper = DatabaseHelper();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  File? _selectedImage;

  late StreamSubscription _intentDataStreamSubscription;

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    final file = files.first;

    setState(() {
      // Проверяваме типа според библиотеката
      if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
        _titleController.text = "Споделен текст/линк";
        
        // В новите версии ТЕКСТЪТ е записан директно в .path
        _contentController.text = file.path; 
        
        _selectedImage = null; // Уверяваме се, че няма стара снимка
      } else if (file.type == SharedMediaType.image) {
        _titleController.text = "Споделена снимка";
        _selectedImage = File(file.path); // Тук .path е истински път до файл
        _contentController.clear();
      }
    });

    // Важно: Подаваме context, за да се отвори панела
    _showAddForm(context);
  }

  @override
  void initState() {
    super.initState();
    _refreshItems();

    // Слуша за нови споделяния (когато приложението е в бекграунд)
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> files) {
      _handleSharedFiles(files);
    }, onError: (err) {
      print("Грешка при стрийм: $err");
    });

    // Слушател 2: За чист текст/линкове (Ако не минават през горния метод)
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
        if (files.isNotEmpty) {
          _handleSharedFiles(files);
        }
      });

    // Проверява за споделяне, с което е стартирано приложението (студен старт)
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        _handleSharedFiles(files);
      }
    });
  }

  void _refreshItems() async {
    final dbHelper = DatabaseHelper();
    final data = await dbHelper.queryAllRows(); // Извличаме всички редове от SQLite
      setState(() {
      _items = data; // Обновяваме списъка с реалните данни
      _isLoading = false; // Спираме индикатора за зареждане
    });
  }

  void _showAddForm(BuildContext context, {Map<String, dynamic>? item}) {
    // 1. Инициализация на данните спрямо това дали е редакция или нов запис
    if (item != null) {
      _titleController.text = item['title'] ?? "";
      _contentController.text = item['content'] ?? "";
      selectedDateTime = item['reminderDate'] != null 
          ? DateTime.parse(item['reminderDate']) 
          : null;
      _selectedImage = item['imagePath'] != null ? File(item['imagePath']) : null;
      _shouldCopyImage = (item['isLocalCopy'] == 1);
    } else {
      // Чистим контролерите за нов запис, ако не са изчистени от споделянето
      // (Ако идваме от _handleSharedFiles, тези полета вече ще са попълнени)
      if (_titleController.text.isEmpty && _contentController.text.isEmpty) {
        _selectedImage = null;
        selectedDateTime = null;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder( // Използваме StatefulBuilder, за да работи Switch и датата вътре в панела
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item == null ? 'Нов запис' : 'Редактиране', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                  ),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Заглавие'),
                  ),
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(labelText: 'Описание / Бележка'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          // Извикваме оригиналната функция и обновяваме състоянието на панела
                          await _pickDateTime(context);
                          setModalState(() {}); 
                        },
                        icon: Icon(Icons.alarm, color: selectedDateTime != null ? Colors.green : Colors.blue),
                        label: Text(
                          selectedDateTime == null 
                            ? 'Напомняне' 
                            : '${selectedDateTime!.day}.${selectedDateTime!.month} в ${selectedDateTime!.hour}:${selectedDateTime!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(color: selectedDateTime != null ? Colors.green : Colors.blue),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          String? finalPath = item?['imagePath']; // Запазваме стария път по подразбиране
                          
                          // Логика за снимката (само ако е променена или е нова)
                          if (_selectedImage != null && _selectedImage!.path != item?['imagePath']) {
                            if (_shouldCopyImage) {
                              finalPath = await FileService.saveImageLocally(_selectedImage!);
                            } else {
                              finalPath = _selectedImage!.path;
                            }
                          }

                          Map<String, dynamic> data = {
                            'title': _titleController.text,
                            'content': _contentController.text,
                            'imagePath': finalPath,
                            'isLocalCopy': _shouldCopyImage ? 1 : 0,
                            'reminderDate': selectedDateTime?.toIso8601String(),
                            'isCompleted': item != null ? item['isCompleted'] : 0,
                          };

                          if (item == null) {
                            await dbHelper.insertItem(data);
                          } else {
                            data['id'] = item['id']; // Добавяме ID за ъпдейта
                            await dbHelper.updateItem(data);
                          }

                          // Изчистване и затваряне
                          _titleController.clear();
                          _contentController.clear();
                          _selectedImage = null;
                          selectedDateTime = null;
                          
                          _refreshItems();
                          Navigator.pop(context);
                        },
                        child: Text(item == null ? 'Запази' : 'Обнови'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text("Копирай снимката локално"),
                    value: _shouldCopyImage,
                    onChanged: (bool value) {
                      // Важно: обновяваме и главното състояние, и това на панела
                      setState(() => _shouldCopyImage = value);
                      setModalState(() => _shouldCopyImage = value);
                    },
                    secondary: const Icon(Icons.storage),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  // Функция за избор на Дата и Час
  Future<void> _pickDateTime(BuildContext context) async {
    // 1. Избор на дата
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      helpText: 'Избери дата за напомняне',
    );

    if (date != null) {
      // 2. Избор на час
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        helpText: 'Избери час',
      );

      if (time != null) {
        setState(() {
          selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
          // В build метода на HomeScreen -> AppBar
          appBar: AppBar(
            title: const Text('My Screenshots'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  showSearch(
                    context: context,
                    delegate: NoteSearchDelegate(
                      items: _items,
                      onSelect: (item) {
                        // Логика за отваряне на детайлите на избраната бележка
                        if (item['imagePath'] != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageDetailScreen(
                                imagePath: item['imagePath'],
                                title: item['title'],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ],
          ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Върти се, докато чакаме базата
          : _items.isEmpty
              ? const Center(child: Text('Няма записи. Натиснете + за начало.'))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Dismissible(
                      key: Key(item['id'].toString()), // Уникален ключ за всеки елемент
                      direction: DismissDirection.endToStart, // Плъзгане само отдясно наляво
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) async {
                        // 1. Изтриваме от базата данни
                        await dbHelper.deleteItem(item['id']);
                        // 2. Премахваме от локалния списък, за да се обнови UI веднага
                        setState(() {
                          _items.removeAt(index);
                        });
                        // 3. Показваме съобщение с опция за връщане (Undo) - по желание
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("${item['title']} е изтрито")),
                        );
                        if (item['imagePath'] != null && item['isLocalCopy'] == 1) {
                          final file = File(item['imagePath']);
                          if (await file.exists()) {
                            await file.delete();
                          }
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: ListTile(
                          leading: item['imagePath'] != null
                              ? Hero(
                                  tag: item['imagePath'],
                                  child: Image.file(File(item['imagePath']), width: 50, height: 50, fit: BoxFit.cover),
                                )
                              : Icon(item['isCompleted'] == 1 ? Icons.check_circle : Icons.note),
                          title: Text(item['title']),
                          subtitle: Text(item['content']),
                          onTap: () {
                            if (item['imagePath'] != null) {
                              // 1. Ако има снимка, отиваме на екрана за голям преглед
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ImageDetailScreen(
                                    imagePath: item['imagePath'],
                                    title: item['title'],
                                  ),
                                ),
                              );
                            } else {
                              // 2. Ако няма снимка, показваме пълния текст в диалогов прозорец
                              _showTextDetails(item);
                            }
                          },
                          onLongPress: () => _showAddForm(context, item: item),
                          trailing: Checkbox(
                            value: item['isCompleted'] == 1,
                            onChanged: (bool? value) async {
                              // Обновяваме в базата данни
                              await dbHelper.database.then((db) {
                                db.update(
                                  'items',
                                  {'isCompleted': value! ? 1 : 0},
                                  where: 'id = ?',
                                  whereArgs: [item['id']],
                                );
                              });
                              _refreshItems(); // Презареждаме списъка
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddForm(context),
        child: const Icon(Icons.add),
      ),
    );
    }

  void _handleSharedText(String text) {
    // Тук автоматично отваряме формата с попълнен текст
    _titleController.text = "Споделен текст";
    _contentController.text = text;
    _showAddForm(context);
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel(); // Важно: затваряме абонамента
    super.dispose();
  }

  void _showTextDetails(Map<String, dynamic> item) {
    final String content = item['content'] ?? "";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['title'] ?? "Детайли"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableLinkify(
                text: content,
                onOpen: (link) async {
                  final Uri url = Uri.parse(link.url);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Неуспешно отваряне на линка")),
                      );
                    }
                  }
                },
                style: const TextStyle(fontSize: 16),
                linkStyle: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Затвори"),
          ),
        ],
      ),
    );
  }
}
