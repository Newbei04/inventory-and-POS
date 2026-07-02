import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/product.dart';
import '../models/stock_movement.dart';
import '../models/price_change.dart';

class ExportImportHelper {
  ExportImportHelper._();

  static Directory? _exportsDir;

  static Future<Directory> getExportsDir() async {
    if (_exportsDir != null) return _exportsDir!;

    // No directory chosen yet — use a sensible default
    Directory? dir;
    if (Platform.isAndroid) {
      try {
        dir = Directory('/storage/emulated/0/Download/price_checker');
        if (!dir.existsSync()) dir.createSync(recursive: true);
      } catch (_) {
        dir = null;
      }
    }
    if (dir == null) {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        dir = Directory('${downloadsDir.path}/price_checker');
      }
    }
    dir ??= Directory(
      '${(await getApplicationDocumentsDirectory()).path}/price_checker',
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _exportsDir = dir;
    return _exportsDir!;
  }

  static Future<bool> pickExportDir() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select export folder',
    );
    if (path == null) return false;
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _exportsDir = dir;
    return true;
  }

  static String getExportsDirPath() {
    return _exportsDir?.path ?? '';
  }

  static Future<String> _saveFile(String name, String ext, List<int> bytes) async {
    final dir = await getExportsDir();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = p.join(dir.path, '${name}_$timestamp.$ext');
    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }

  static Future<String> _saveFileFromString(String name, String ext, String content) async {
    final dir = await getExportsDir();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = p.join(dir.path, '${name}_$timestamp.$ext');
    final file = File(path);
    await file.writeAsString(content);
    return path;
  }

  /// Open the share sheet for a previously saved file.
  static Future<void> shareFile(String filePath, {String? text}) async {
    await Share.shareXFiles([XFile(filePath)], text: text);
  }

  // ── Export ──

  static String _imageToBase64(String imagePath) {
    try {
      final file = File(imagePath);
      if (file.existsSync()) {
        return base64Encode(file.readAsBytesSync());
      }
    } catch (_) {}
    return '';
  }

  static String _toCSV(List<Product> products) {
    final rows = <List<dynamic>>[
      [
        'barcode', 'name', 'category', 'price', 'cost',
        'quantity', 'unit', 'description', 'image_data',
        'date_added', 'date_updated',
      ],
      for (final prod in products)
        [
          prod.barcode,
          prod.name,
          prod.category,
          prod.price,
          prod.cost,
          prod.quantity,
          prod.unit,
          prod.description,
          _imageToBase64(prod.imagePath),
          prod.dateAdded,
          prod.dateUpdated,
        ],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  static String _toJSON(List<Product> products) {
    final data = products.map((p) => {
      'barcode': p.barcode,
      'name': p.name,
      'category': p.category,
      'price': p.price,
      'cost': p.cost,
      'quantity': p.quantity,
      'unit': p.unit,
      'description': p.description,
      'image_data': _imageToBase64(p.imagePath),
      'date_added': p.dateAdded,
      'date_updated': p.dateUpdated,
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Future<File> _toExcel(List<Product> products) async {
    final excel = Excel.createExcel();
    final sheet = excel['Products'];

    sheet.appendRow([
      TextCellValue('barcode'),
      TextCellValue('name'),
      TextCellValue('category'),
      TextCellValue('price'),
      TextCellValue('cost'),
      TextCellValue('quantity'),
      TextCellValue('unit'),
      TextCellValue('description'),
      TextCellValue('image_data'),
      TextCellValue('date_added'),
      TextCellValue('date_updated'),
    ]);

    for (final prod in products) {
      sheet.appendRow([
        TextCellValue(prod.barcode),
        TextCellValue(prod.name),
        TextCellValue(prod.category),
        DoubleCellValue(prod.price),
        DoubleCellValue(prod.cost),
        IntCellValue(prod.quantity),
        TextCellValue(prod.unit),
        TextCellValue(prod.description),
        TextCellValue(_imageToBase64(prod.imagePath)),
        TextCellValue(prod.dateAdded),
        TextCellValue(prod.dateUpdated),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to encode Excel file');
    final path = await _saveFile('products_export', 'xlsx', bytes);
    return File(path);
  }

  /// Export all products in the given format and return the file path.
  static Future<String> exportProducts({
    required List<Product> products,
    required String format,
  }) async {
    switch (format) {
      case 'csv':
        final csv = _toCSV(products);
        return _saveFileFromString('products_export', 'csv', csv);
      case 'json':
        final json = _toJSON(products);
        return _saveFileFromString('products_export', 'json', json);
      case 'xlsx':
        final file = await _toExcel(products);
        return file.path;
      default:
        throw ArgumentError('Unsupported format: $format');
    }
  }

  /// Export all data types into a single Excel file with multiple sheets.
  static Future<File> _toCombinedExcel({
    required List<Product> products,
    required List<StockMovement> movements,
    required List<PriceChange> changes,
  }) async {
    final excel = Excel.createExcel();

    // Sheet 1: Products
    final productSheet = excel['Products'];
    productSheet.appendRow([
      TextCellValue('barcode'),
      TextCellValue('name'),
      TextCellValue('category'),
      TextCellValue('price'),
      TextCellValue('cost'),
      TextCellValue('quantity'),
      TextCellValue('unit'),
      TextCellValue('description'),
      TextCellValue('image_data'),
      TextCellValue('date_added'),
      TextCellValue('date_updated'),
    ]);
    for (final prod in products) {
      productSheet.appendRow([
        TextCellValue(prod.barcode),
        TextCellValue(prod.name),
        TextCellValue(prod.category),
        DoubleCellValue(prod.price),
        DoubleCellValue(prod.cost),
        IntCellValue(prod.quantity),
        TextCellValue(prod.unit),
        TextCellValue(prod.description),
        TextCellValue(_imageToBase64(prod.imagePath)),
        TextCellValue(prod.dateAdded),
        TextCellValue(prod.dateUpdated),
      ]);
    }

    // Sheet 2: Stock Movements
    final stockSheet = excel['Stock Movements'];
    stockSheet.appendRow([
      TextCellValue('id'),
      TextCellValue('product_id'),
      TextCellValue('product_name'),
      TextCellValue('old_quantity'),
      TextCellValue('new_quantity'),
      TextCellValue('delta'),
      TextCellValue('type'),
      TextCellValue('date'),
    ]);
    for (final m in movements) {
      stockSheet.appendRow([
        IntCellValue(m.id ?? 0),
        IntCellValue(m.productId),
        TextCellValue(m.productName),
        IntCellValue(m.oldQuantity),
        IntCellValue(m.newQuantity),
        IntCellValue(m.delta),
        TextCellValue(m.type),
        TextCellValue(m.date),
      ]);
    }

    // Sheet 3: Price Changes
    final priceSheet = excel['Price Changes'];
    priceSheet.appendRow([
      TextCellValue('id'),
      TextCellValue('product_id'),
      TextCellValue('product_name'),
      TextCellValue('old_price'),
      TextCellValue('new_price'),
      TextCellValue('old_cost'),
      TextCellValue('new_cost'),
      TextCellValue('date'),
    ]);
    for (final c in changes) {
      priceSheet.appendRow([
        IntCellValue(c.id ?? 0),
        IntCellValue(c.productId),
        TextCellValue(c.productName),
        DoubleCellValue(c.oldPrice),
        DoubleCellValue(c.newPrice),
        DoubleCellValue(c.oldCost),
        DoubleCellValue(c.newCost),
        TextCellValue(c.date),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to encode Excel file');
    final path = await _saveFile('inventory_export', 'xlsx', bytes);
    return File(path);
  }

  /// Export all data types into a single Excel file and return the path.
  static Future<String> exportCombined({
    required List<Product> products,
    required List<StockMovement> movements,
    required List<PriceChange> changes,
  }) async {
    final file = await _toCombinedExcel(
      products: products,
      movements: movements,
      changes: changes,
    );
    return file.path;
  }

  // ── Log Export ──

  static String _stockMovementsToCSV(List<StockMovement> movements) {
    final rows = <List<dynamic>>[
      ['id', 'product_id', 'product_name', 'old_quantity', 'new_quantity',
       'delta', 'type', 'date'],
      for (final m in movements)
        [m.id, m.productId, m.productName, m.oldQuantity, m.newQuantity,
         m.delta, m.type, m.date],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  static String _priceChangesToCSV(List<PriceChange> changes) {
    final rows = <List<dynamic>>[
      ['id', 'product_id', 'product_name', 'old_price', 'new_price',
       'old_cost', 'new_cost', 'date'],
      for (final c in changes)
        [c.id, c.productId, c.productName, c.oldPrice, c.newPrice,
         c.oldCost, c.newCost, c.date],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  static String _stockMovementsToJSON(List<StockMovement> movements) {
    final data = movements.map((m) => {
      'id': m.id,
      'product_id': m.productId,
      'product_name': m.productName,
      'old_quantity': m.oldQuantity,
      'new_quantity': m.newQuantity,
      'delta': m.delta,
      'type': m.type,
      'date': m.date,
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static String _priceChangesToJSON(List<PriceChange> changes) {
    final data = changes.map((c) => {
      'id': c.id,
      'product_id': c.productId,
      'product_name': c.productName,
      'old_price': c.oldPrice,
      'new_price': c.newPrice,
      'old_cost': c.oldCost,
      'new_cost': c.newCost,
      'date': c.date,
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Future<File> _stockMovementsToExcel(List<StockMovement> movements) async {
    final excel = Excel.createExcel();
    final sheet = excel['Stock Movements'];

    sheet.appendRow([
      TextCellValue('id'),
      TextCellValue('product_id'),
      TextCellValue('product_name'),
      TextCellValue('old_quantity'),
      TextCellValue('new_quantity'),
      TextCellValue('delta'),
      TextCellValue('type'),
      TextCellValue('date'),
    ]);

    for (final m in movements) {
      sheet.appendRow([
        IntCellValue(m.id ?? 0),
        IntCellValue(m.productId),
        TextCellValue(m.productName),
        IntCellValue(m.oldQuantity),
        IntCellValue(m.newQuantity),
        IntCellValue(m.delta),
        TextCellValue(m.type),
        TextCellValue(m.date),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to encode Excel file');
    final path = await _saveFile('stock_movements_export', 'xlsx', bytes);
    return File(path);
  }

  static Future<File> _priceChangesToExcel(List<PriceChange> changes) async {
    final excel = Excel.createExcel();
    final sheet = excel['Price Changes'];

    sheet.appendRow([
      TextCellValue('id'),
      TextCellValue('product_id'),
      TextCellValue('product_name'),
      TextCellValue('old_price'),
      TextCellValue('new_price'),
      TextCellValue('old_cost'),
      TextCellValue('new_cost'),
      TextCellValue('date'),
    ]);

    for (final c in changes) {
      sheet.appendRow([
        IntCellValue(c.id ?? 0),
        IntCellValue(c.productId),
        TextCellValue(c.productName),
        DoubleCellValue(c.oldPrice),
        DoubleCellValue(c.newPrice),
        DoubleCellValue(c.oldCost),
        DoubleCellValue(c.newCost),
        TextCellValue(c.date),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to encode Excel file');
    final path = await _saveFile('price_changes_export', 'xlsx', bytes);
    return File(path);
  }

  /// Export stock movements and return the file path.
  static Future<String> exportStockMovements({
    required List<StockMovement> movements,
    required String format,
  }) async {
    switch (format) {
      case 'csv':
        final csv = _stockMovementsToCSV(movements);
        return _saveFileFromString('stock_movements_export', 'csv', csv);
      case 'json':
        final json = _stockMovementsToJSON(movements);
        return _saveFileFromString('stock_movements_export', 'json', json);
      case 'xlsx':
        final file = await _stockMovementsToExcel(movements);
        return file.path;
      default:
        throw ArgumentError('Unsupported format: $format');
    }
  }

  /// Export price changes and return the file path.
  static Future<String> exportPriceChanges({
    required List<PriceChange> changes,
    required String format,
  }) async {
    switch (format) {
      case 'csv':
        final csv = _priceChangesToCSV(changes);
        return _saveFileFromString('price_changes_export', 'csv', csv);
      case 'json':
        final json = _priceChangesToJSON(changes);
        return _saveFileFromString('price_changes_export', 'json', json);
      case 'xlsx':
        final file = await _priceChangesToExcel(changes);
        return file.path;
      default:
        throw ArgumentError('Unsupported format: $format');
    }
  }

  // ── Import ──

  /// Generate a template CSV file and save it to the downloads directory.
  static Future<String> downloadTemplate() async {
    final dir = await getExportsDir();
    final rows = <List<dynamic>>[
      [
        'barcode', 'name', 'category', 'price', 'cost',
        'quantity', 'unit', 'description', 'image_data',
      ],
      [
        '123456789', 'Sample Product', 'General', '99.99', '50.00',
        '100', 'pcs', 'Optional description', '',
      ],
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final file = File(p.join(dir.path, 'import_template.csv'));
    file.writeAsStringSync(csv);
    return file.path;
  }

  static Directory? _imageDir;

  static Future<Directory> _getImageDir() async {
    if (_imageDir != null) return _imageDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _imageDir = Directory(p.join(appDir.path, 'imported_images'));
    if (!_imageDir!.existsSync()) _imageDir!.createSync(recursive: true);
    return _imageDir!;
  }

  /// Let the user pick a file and return parsed products.
  static Future<ImportResult> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json', 'xlsx'],
    );
    if (result == null || result.files.single.path == null) {
      return ImportResult(products: [], errors: []);
    }
    return importFromFile(result.files.single.path!);
  }

  /// Detect format by extension and parse accordingly.
  static Future<ImportResult> importFromFile(String filePath) async {
    final ext = p.extension(filePath).toLowerCase();
    try {
      switch (ext) {
        case '.csv':
          return _fromCSV(filePath);
        case '.json':
          return _fromJSON(filePath);
        case '.xlsx':
          return _fromExcel(filePath);
        default:
          return ImportResult(
            products: [],
            errors: ['Unsupported file format: $ext'],
          );
      }
    } catch (e) {
      return ImportResult(products: [], errors: ['Import failed: $e']);
    }
  }

  static Future<ImportResult> _fromCSV(String filePath) async {
    final content = await File(filePath).readAsString();
    final rows = const CsvToListConverter().convert(content);
    if (rows.length < 2) {
      return ImportResult(products: [], errors: ['File has no data rows']);
    }
    return _parseRows(rows);
  }

  static Future<ImportResult> _fromJSON(String filePath) async {
    final content = await File(filePath).readAsString();
    final data = json.decode(content) as List<dynamic>;
    final rows = <List<dynamic>>[
      [
        'barcode', 'name', 'category', 'price', 'cost',
        'quantity', 'unit', 'description', 'image_data',
        'date_added', 'date_updated',
      ],
      for (final e in data)
        [
          _val(e, 'barcode'),
          _val(e, 'name'),
          _val(e, 'category'),
          _val(e, 'price'),
          _val(e, 'cost'),
          _val(e, 'quantity'),
          _val(e, 'unit', 'pc'),
          _val(e, 'description'),
          _val(e, 'image_data'),
          _val(e, 'date_added', DateTime.now().toIso8601String()),
          _val(e, 'date_updated', DateTime.now().toIso8601String()),
        ],
    ];
    return _parseRows(rows);
  }

  static String _val(dynamic obj, String key, [String fallback = '']) {
    if (obj is Map) {
      final v = obj[key];
      return v?.toString() ?? fallback;
    }
    return fallback;
  }

  static Future<ImportResult> _fromExcel(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return ImportResult(products: [], errors: ['Empty Excel file']);
    }
    final sheet = excel.tables.values.first;
    if (sheet.rows.length < 2) {
      return ImportResult(products: [], errors: ['Excel file has no data rows']);
    }

    final allRows = <List<dynamic>>[
      sheet.rows.first.map((c) => c?.value?.toString() ?? '').toList(),
      ...sheet.rows.sublist(1).map(
        (r) => r.map((c) => c?.value?.toString() ?? '').toList(),
      ),
    ];
    return _parseRows(allRows);
  }

  static Future<ImportResult> _parseRows(List<List<dynamic>> rows) async {
    final headers =
        rows[0].map((e) => e.toString().trim().toLowerCase()).toList();
    final products = <Product>[];
    final errors = <String>[];
    final now = DateTime.now().toIso8601String();
    final imageDir = await _getImageDir();

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;
      if (row.every((e) => e.toString().trim().isEmpty)) continue;

      final data = <String, dynamic>{};
      for (var j = 0; j < headers.length; j++) {
        data[headers[j]] = j < row.length ? row[j] : '';
      }

      try {
        final imagePath = _saveImageFromBase64(
          _str(data, 'image_data', ''),
          _str(data, 'barcode', 'unknown'),
          imageDir,
        );
        final product = Product(
          barcode: _str(data, 'barcode', ''),
          name: _str(data, 'name', ''),
          category: _str(data, 'category', ''),
          price: _num(data, 'price', 0),
          cost: _num(data, 'cost', 0),
          quantity: _int(data, 'quantity', 0),
          unit: _str(data, 'unit', 'pc'),
          description: _str(data, 'description', ''),
          imagePath: imagePath,
          dateAdded: _str(data, 'date_added', now),
          dateUpdated: _str(data, 'date_updated', now),
        );
        if (product.barcode.isEmpty || product.name.isEmpty) {
          errors.add('Row $i: missing barcode or name');
        } else {
          products.add(product);
        }
      } catch (e) {
        errors.add('Row $i: $e');
      }
    }

    return ImportResult(products: products, errors: errors);
  }

  /// Decode base64 image data, save to app documents directory.
  static String _saveImageFromBase64(
      String base64data, String barcode, Directory imageDir) {
    if (base64data.isEmpty) return '';
    try {
      final bytes = base64Decode(base64data);
      final file = File(p.join(imageDir.path,
          'import_${barcode}_${DateTime.now().millisecondsSinceEpoch}.jpg'));
      file.writeAsBytesSync(bytes);
      return file.path;
    } catch (_) {
      return '';
    }
  }

  static String _str(Map<String, dynamic> data, String key, String fallback) {
    final v = data[key];
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static double _num(Map<String, dynamic> data, String key, num fallback) {
    final v = data[key];
    if (v == null) return fallback.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? fallback.toDouble();
  }

  static int _int(Map<String, dynamic> data, String key, int fallback) {
    final v = data[key];
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? fallback;
  }
}

class ImportResult {
  final List<Product> products;
  final List<String> errors;

  ImportResult({required this.products, required this.errors});

  int get successCount => products.length;
  int get errorCount => errors.length;
  bool get hasErrors => errors.isNotEmpty;
}
