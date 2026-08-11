import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;
  
  static Future<Database> get database async {
    if(_db!= null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static _initDB() async {
    String path = join(await getDatabasesPath(), 'restro_pro.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  static _onCreate(Database db, int v) async {
    await db.execute('CREATE TABLE stocks(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, qty REAL, unit TEXT, unit_price REAL, low_alert REAL)');
    await db.execute('CREATE TABLE sales(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, total REAL)');
    await db.execute('CREATE TABLE sale_items(id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER, stock_id INTEGER, qty REAL, price REAL)');
    await db.execute('CREATE TABLE topups(id INTEGER PRIMARY KEY AUTOINCREMENT, stock_id INTEGER, qty REAL, date TEXT)');
  }

  // Stocks
  static Future<int> addStock(Map<String, dynamic> data) => database.then((db)=>db.insert('stocks', data));
  
  static Future<List<Map<String, dynamic>>> getStocks() => database.then((db)=>db.query('stocks', orderBy: 'name ASC'));
  
  static Future<int> updateStock(int id, Map<String, dynamic> data) => database.then((db)=>db.update('stocks', data, where: 'id=?', whereArgs: [id]));
  
  static Future<int> deleteStock(int id) => database.then((db)=>db.delete('stocks', where: 'id=?', whereArgs: [id]));
  
  static Future updateStockQty(int id, double newQty) async {
    final db = await database;
    await db.update('stocks', {'qty': newQty}, where: 'id =?', whereArgs: [id]);
  }

  static Future<int> topUpStock(int id, double qty) async {
    final db = await database;
    await db.rawUpdate('UPDATE stocks SET qty = qty +? WHERE id =?', [qty, id]);
    return db.insert('topups', {'stock_id': id, 'qty': qty, 'date': DateTime.now().toIso8601String()});
  }

  // Sales
  static Future<int> makeSale(List<Map<String, dynamic>> items, double total) async {
    final db = await database;
    int saleId = await db.insert('sales', {'date': DateTime.now().toIso8601String(), 'total': total});
    for(var item in items){
      await db.insert('sale_items', {
        'sale_id': saleId,
        'stock_id': item['stock_id'],
        'qty': item['qty'],
        'price': item['price']
      });
      await db.rawUpdate('UPDATE stocks SET qty = qty -? WHERE id =?', [item['qty'], item['stock_id']]);
    }
    return saleId;
  }

  static Future<List<Map<String, dynamic>>> getSales() => database.then((db)=>db.query('sales', orderBy: 'id DESC'));
  
  static Future<List<Map<String, dynamic>>> getTopUps() => database.then((db)=>db.query('topups', orderBy: 'id DESC'));
  
  static Future<double> getTotalRevenue() async {
    final db = await database;
    var res = await db.rawQuery('SELECT SUM(total) as total FROM sales');
    return (res.first['total'] as num?)?.toDouble()?? 0.0;
  }
} // <- THIS BRACE WAS MISSING