import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
    String path = join(await getDatabasesPath(), 'business_organizer.db');
    return await openDatabase(
      path,
      version: 2, // Вдигаме версията заради новите полета
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            content TEXT,
            imagePath TEXT,
            isLocalCopy INTEGER, 
            reminderTime TEXT, 
            color INTEGER,
            isCompleted INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) {
        // Тъй като ще преинсталирате, това е просто за застраховка
        if (oldVersion < 2) {
          db.execute("ALTER TABLE items ADD COLUMN color INTEGER");
          // Ако името е било различно, тук е мястото за миграция, 
          // но преинсталацията е най-сигурният вариант.
        }
      },
    );
  }

  Future<int> insertItem(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('items', row);
  }

  Future<List<Map<String, dynamic>>> queryAllRows() async {
    Database db = await database;
    return await db.query('items', orderBy: "id DESC");
  }

  Future<int> deleteItem(int id) async {
    Database db = await database; 
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }  

  Future<int> updateItem(Map<String, dynamic> row) async {
    Database db = await database;
    int id = row['id'];
    return await db.update('items', row, where: 'id = ?', whereArgs: [id]);
  }
}

// Future<List<Map<String, dynamic>>> getItems() async {
//   final db = await instance.database;
//   // Връщаме всички редове от таблица 'items'
//   return await db.query('items'); 
// }