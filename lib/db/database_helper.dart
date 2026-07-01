import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/product.dart';
import '../../models/stock_movement.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'inventory_scanner.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            barcode TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            category TEXT,
            price REAL NOT NULL DEFAULT 0,
            cost REAL NOT NULL DEFAULT 0,
            quantity INTEGER NOT NULL DEFAULT 0,
            unit TEXT,
            description TEXT,
            image_path TEXT DEFAULT '',
            date_added TEXT,
            date_updated TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_barcode ON products(barcode)');
        await _createStockMovementsTable(db);
        await _createPriceChangesTable(db);
        await _createSettingsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
              "ALTER TABLE products ADD COLUMN image_path TEXT DEFAULT ''",
            );
          } catch (_) {}
          await _createStockMovementsTable(db);
        }
        if (oldVersion < 3) {
          await _createPriceChangesTable(db);
        }
        if (oldVersion < 4) {
          await _createSettingsTable(db);
        }
      },
    );
  }

  Future<void> _createStockMovementsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        old_quantity INTEGER NOT NULL,
        new_quantity INTEGER NOT NULL,
        delta INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'adjustment',
        date TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_movement_product ON stock_movements(product_id)',
    );
  }

  // ── Settings ──

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<bool> isPasswordSet() async {
    final pw = await getSetting('edit_password');
    return pw != null && pw.isNotEmpty;
  }

  Future<bool> verifyPassword(String input) async {
    final stored = await getSetting('edit_password');
    if (stored == null) return false;
    return stored == input;
  }

  Future<void> setPassword(String password) async {
    await setSetting('edit_password', password);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<List<Product>> getAllProducts({String? search}) async {
    final db = await database;
    List<Map<String, dynamic>> rows;
    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      rows = await db.query(
        'products',
        where: 'name LIKE ? OR barcode LIKE ? OR category LIKE ?',
        whereArgs: [q, q, q],
        orderBy: 'name COLLATE NOCASE ASC',
      );
    } else {
      rows = await db.query('products', orderBy: 'name COLLATE NOCASE ASC');
    }
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  /// Insert or update by barcode. Used for scanning restock and for import.
  Future<void> upsertByBarcode(Product product) async {
    final db = await database;

    final existing = await getProductByBarcode(product.barcode);

    if (existing == null) {
      await db.insert('products', product.toMap());
    } else {
      await db.update(
        'products',
        {
          'barcode': product.barcode,
          'name': product.name,
          'category': product.category,
          'price': product.price,
          'cost': product.cost,
          'quantity': product.quantity,
          'unit': product.unit,
          'description': product.description,
          'image_path': product.imagePath,
          'date_added': existing.dateAdded,
          'date_updated': DateTime.now().toIso8601String(),
        },
        where: 'id=?',
        whereArgs: [existing.id],
      );
    }
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;

    final rows = await db.query(
      'products',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return Product.fromMap(rows.first);
  }

  Future<List<Product>> getLowStockProducts({int limit = 5}) async {
    final db = await database;

    final rows = await db.query(
      'products',
      where: 'quantity <= ?',
      whereArgs: [limit],
      orderBy: 'quantity ASC',
    );

    return rows.map(Product.fromMap).toList();
  }

  Future<double> getInventoryValue() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT SUM(price * quantity) AS total FROM products',
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getInventoryCost() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT SUM(cost * quantity) AS total FROM products',
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<int> getTotalQuantity() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT SUM(quantity) AS qty FROM products',
    );

    return (result.first['qty'] as num?)?.toInt() ?? 0;
  }

  Future<bool> barcodeExists(String barcode) async {
    final db = await database;

    final rows = await db.query(
      'products',
      columns: ['id'],
      where: 'barcode=?',
      whereArgs: [barcode],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<List<String>> getCategories() async {
    final db = await database;

    final rows = await db.rawQuery('''
    SELECT DISTINCT category
    FROM products
    WHERE category <> ''
    ORDER BY category
  ''');

    return rows.map((e) => e['category'].toString()).toList();
  }

  Future<List<Product>> getByCategory(String category) async {
    final db = await database;

    final rows = await db.query(
      'products',
      where: 'category=?',
      whereArgs: [category],
      orderBy: 'name',
    );

    return rows.map(Product.fromMap).toList();
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> adjustStock(int id, int deltaQuantity) async {
    final db = await database;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return 0;
    final current = Product.fromMap(rows.first);
    final newQty = current.quantity + deltaQuantity;
    final clamped = newQty < 0 ? 0 : newQty;
    await db.update(
      'products',
      {
        'quantity': clamped,
        'date_updated': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _logMovement(
      productId: id,
      productName: current.name,
      oldQuantity: current.quantity,
      newQuantity: clamped,
      type: deltaQuantity > 0 ? 'add' : 'sale',
    );
    return clamped;
  }

  // ── Stock Movements ──

  Future<void> logStockChange({
    required int productId,
    required String productName,
    required int oldQuantity,
    required int newQuantity,
    String type = 'adjustment',
  }) async {
    await _logMovement(
      productId: productId,
      productName: productName,
      oldQuantity: oldQuantity,
      newQuantity: newQuantity,
      type: type,
    );
  }

  Future<void> _logMovement({
    required int productId,
    required String productName,
    required int oldQuantity,
    required int newQuantity,
    required String type,
  }) async {
    final db = await database;
    await db.insert('stock_movements', {
      'product_id': productId,
      'product_name': productName,
      'old_quantity': oldQuantity,
      'new_quantity': newQuantity,
      'delta': newQuantity - oldQuantity,
      'type': type,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<List<StockMovement>> getStockMovements({int? limit}) async {
    final db = await database;
    final rows = await db.query(
      'stock_movements',
      orderBy: 'date DESC',
      limit: limit,
    );
    return rows.map((r) => StockMovement.fromMap(r)).toList();
  }

  Future<List<StockMovement>> getStockMovementsByProduct(int productId) async {
    final db = await database;
    final rows = await db.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'date DESC',
    );
    return rows.map((r) => StockMovement.fromMap(r)).toList();
  }

  // ── Price Changes ──

  Future<void> _createPriceChangesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS price_changes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        old_price REAL,
        new_price REAL,
        old_cost REAL,
        new_cost REAL,
        date TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_price_changes_product ON price_changes(product_id)',
    );
  }

  Future<void> logPriceChange({
    required int productId,
    required String productName,
    required double oldPrice,
    required double newPrice,
    required double oldCost,
    required double newCost,
  }) async {
    final db = await database;
    await db.insert('price_changes', {
      'product_id': productId,
      'product_name': productName,
      'old_price': oldPrice,
      'new_price': newPrice,
      'old_cost': oldCost,
      'new_cost': newCost,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPriceChanges({int? limit}) async {
    final db = await database;
    return db.query(
      'price_changes',
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getPriceChangesByProduct(
      int productId) async {
    final db = await database;
    return db.query(
      'price_changes',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'date DESC',
    );
  }

  Future<int> clearAll() async {
    final db = await database;
    await db.delete('stock_movements');
    return db.delete('products');
  }

  Future<int> count() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM products');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
