import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'business_organizer.db');

    return await openDatabase(
      path,
      version: 1, // Версия 1
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        content TEXT,
        imagePath TEXT,
        reminderTime TEXT,
        color INTEGER,
        isCompleted INTEGER DEFAULT 0,
        isLocalCopy INTEGER DEFAULT 0,
        tags TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Логика за бъдещи миграции
  }

  // Вмъкване на запис
  Future<int> insertItem(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('notes', row);
  }

  // Извличане на всички записи
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    final db = await database;
    return await db.query('notes', orderBy: "id DESC");
  }

  // Обновяване на запис с проверка за ID
  Future<int> updateItem(Map<String, dynamic> row) async {
    final db = await database;
    int? id = row['id'];
    // Проверка дали ID съществува, за да не се прави невалидна заявка
    if (id == null) {
      print("Опит за обновяване без ID!");
      return 0;
    }
    return await db.update('notes', row, where: 'id = ?', whereArgs: [id]);
  }

  // Изтриване на запис
  Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}
// Future<List<Map<String, dynamic>>> getItems() async {
//   final db = await instance.database;
//   // Връщаме всички редове от таблица 'items'
//   return await db.query('items'); 
// }