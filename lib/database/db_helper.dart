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
    return await openDatabase(path, version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  static _onCreate(Database db, int v) async {
    // 1. STOCKS - Added initial_qty
    await db.execute('''
      CREATE TABLE stocks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        qty REAL,
        initial_qty REAL,
        unit TEXT,
        unit_price REAL,
        low_alert REAL
      )
    ''');

    // 2. SALES
    await db.execute('CREATE TABLE sales(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, total REAL)');

    // 3. SALE_ITEMS
    await db.execute('CREATE TABLE sale_items(id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER, stock_id INTEGER, qty REAL, price REAL)');

    // 4. TOPUPS
    await db.execute('CREATE TABLE topups(id INTEGER PRIMARY KEY AUTOINCREMENT, stock_id INTEGER, qty REAL, date TEXT)');

    // 5. SETTINGS - For total revenue
    await db.execute('CREATE TABLE settings(id INTEGER PRIMARY KEY, total_revenue REAL)');
    await db.insert('settings', {'id': 1, 'total_revenue': 0.0});

    // 6. STOCK_HISTORY - For graphs
    await db.execute('''
      CREATE TABLE stock_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_id INTEGER,
        type TEXT, -- 'SALE' or 'TOPUP'
        qty_change REAL,
        qty_after REAL,
        date INTEGER, -- timestamp
        FOREIGN KEY(stock_id) REFERENCES stocks(id) ON DELETE CASCADE
      )
    ''');
  }

  static _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if(oldVersion < 2) {
      // Add new columns/tables for v2
      await db.execute('ALTER TABLE stocks ADD COLUMN initial_qty REAL');

      await db.execute('CREATE TABLE IF NOT EXISTS settings(id INTEGER PRIMARY KEY, total_revenue REAL)');
      var settings = await db.query('settings');
      if(settings.isEmpty) await db.insert('settings', {'id': 1, 'total_revenue': 0.0});

      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_history(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          stock_id INTEGER,
          type TEXT,
          qty_change REAL,
          qty_after REAL,
          date INTEGER,
          FOREIGN KEY(stock_id) REFERENCES stocks(id) ON DELETE CASCADE
        )
      ''');
    }
  }

  // HELPER: Log history
  static Future _logHistory(int stockId, String type, double qtyChange, double qtyAfter) async {
    final db = await database;
    await db.insert('stock_history', {
      'stock_id': stockId,
      'type': type,
      'qty_change': qtyChange,
      'qty_after': qtyAfter,
      'date': DateTime.now().millisecondsSinceEpoch
    });
  }

  // Stocks
  static Future<int> addStock(Map<String, dynamic> data) async {
    final db = await database;
    // Set initial_qty = qty if not provided
    data['initial_qty'] = data['initial_qty']?? data['qty'];
    int id = await db.insert('stocks', data);
    await _logHistory(id, 'TOPUP', (data['qty'] as num).toDouble(), (data['qty'] as num).toDouble());
    return id;
  }

  static Future<List<Map<String, dynamic>>> getStocks() async {
    final db = await database;
    return db.query('stocks', orderBy: 'name ASC');
  }

  static Future<int> updateStock(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update('stocks', data, where: 'id=?', whereArgs: [id]);
  }

  static Future<int> deleteStock(int id) async {
    final db = await database;
    // 1. Get stock to calculate revenue to deduct
    var stockList = await db.query('stocks', where: 'id=?', whereArgs: [id]);
    if(stockList.isNotEmpty) {
      var stock = stockList.first;
      double initial = ((stock['initial_qty']?? stock['qty']) as num).toDouble();
      double current = (stock['qty'] as num).toDouble();
      double soldQty = initial - current;
      double revenueToDeduct = soldQty * (stock['unit_price'] as num).toDouble();

      // 2. Deduct from total revenue
      await db.rawUpdate('UPDATE settings SET total_revenue = total_revenue -? WHERE id = 1', [revenueToDeduct]);
    }

    // 3. Delete stock + history
    await db.delete('stock_history', where: 'stock_id=?', whereArgs: [id]);
    return db.delete('stocks', where: 'id=?', whereArgs: [id]);
  }

  static Future updateStockQty(int id, double newQty) async {
    final db = await database;
    await db.update('stocks', {'qty': newQty}, where: 'id =?', whereArgs: [id]);
  }

  static Future<int> topUpStock(int id, double qty) async {
    final db = await database;
    var stock = (await db.query('stocks', where: 'id =?', whereArgs: [id])).first;
    double newQty = (stock['qty'] as num).toDouble() + qty;

    await db.update('stocks', {'qty': newQty}, where: 'id =?', whereArgs: [id]);
    await db.insert('topups', {'stock_id': id, 'qty': qty, 'date': DateTime.now().toIso8601String()});
    await _logHistory(id, 'TOPUP', qty, newQty);
    return 1;
  }

  // Sales
  static Future<int> makeSale(List<Map<String, dynamic>> items, double total) async {
    final db = await database;
    // 1. Add to total revenue
    await db.rawUpdate('UPDATE settings SET total_revenue = total_revenue +? WHERE id = 1', [total]);

    int saleId = await db.insert('sales', {'date': DateTime.now().toIso8601String(), 'total': total});
    for(var item in items){
      await db.insert('sale_items', {
        'sale_id': saleId,
        'stock_id': item['stock_id'],
        'qty': item['qty'],
        'price': item['price']
      });

      var stock = (await db.query('stocks', where: 'id =?', whereArgs: [item['stock_id']])).first;
      double newQty = (stock['qty'] as num).toDouble() - (item['qty'] as num).toDouble();
      await db.update('stocks', {'qty': newQty}, where: 'id =?', whereArgs: [item['stock_id']]);
      await _logHistory(item['stock_id'], 'SALE', -(item['qty'] as num).toDouble(), newQty);
    }
    return saleId;
  }

  static Future<List<Map<String, dynamic>>> getSales() => database.then((db)=>db.query('sales', orderBy: 'id DESC'));

  static Future<List<Map<String, dynamic>>> getTopUps() => database.then((db)=>db.query('topups', orderBy: 'id DESC'));

  static Future<double> getTotalRevenue() async {
    final db = await database;
    var res = await db.query('settings', where: 'id = 1');
    return (res.first['total_revenue'] as num?)?.toDouble()?? 0.0;
  }

  // NEW: For graphs
  static Future<List<Map<String, dynamic>>> getStockHistory(int stockId) async {
    final db = await database;
    return await db.query('stock_history', where: 'stock_id =?', whereArgs: [stockId], orderBy: 'date ASC');
  }

  // NEW: Reset Total Revenue to Zero - Used by HomePage
  static Future<void> resetTotalRevenue() async {
    final db = await database;
    await db.update('settings', {'total_revenue': 0.0}, where: 'id = 1');
  }

  // NEW: Clear All Sales/Receipts - Used by ReportsPage
  static Future<void> clearAllSales() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sale_items'); // delete line items first
      await txn.delete('sales'); // then delete sales
    });
    // Reset revenue to 0 after clearing
    await resetTotalRevenue();
  }

  // NEW: Delete All
  static Future deleteAllData() async {
    final db = await database;
    await db.delete('stocks');
    await db.delete('sales');
    await db.delete('sale_items');
    await db.delete('topups');
    await db.delete('stock_history');
    await db.update('settings', {'total_revenue': 0.0}, where: 'id = 1');
  }
}