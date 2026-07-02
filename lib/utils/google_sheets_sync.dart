import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

import '../db/database_helper.dart';

class SyncResult {
  final String url;
  final int productsSynced;
  final int stockMovementsSynced;
  final int priceChangesSynced;
  final int receiptsSynced;
  final String? error;

  SyncResult({
    required this.url,
    this.productsSynced = 0,
    this.stockMovementsSynced = 0,
    this.priceChangesSynced = 0,
    this.receiptsSynced = 0,
    this.error,
  });

  bool get isSuccess => error == null;
}

class GoogleSheetsSync {
  static final _googleSignIn = GoogleSignIn(
    scopes: [SheetsApi.spreadsheetsScope],
  );

  static Future<SyncResult> syncAll() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return SyncResult(url: '', error: 'Sign in was cancelled.');
      }

      final client = await _googleSignIn.authenticatedClient();
      if (client == null) {
        return SyncResult(url: '', error: 'Failed to get authenticated client.');
      }

      final sheets = SheetsApi(client);

      final spreadsheet = await sheets.spreadsheets.create(
        Spreadsheet(
          properties: SpreadsheetProperties(title: 'Price Checker — Inventory'),
          sheets: [
            Sheet(properties: SheetProperties(title: 'Products')),
            Sheet(properties: SheetProperties(title: 'Stock Movements')),
            Sheet(properties: SheetProperties(title: 'Price Changes')),
            Sheet(properties: SheetProperties(title: 'Receipts')),
          ],
        ),
      );

      final spreadsheetId = spreadsheet.spreadsheetId;
      if (spreadsheetId == null) {
        client.close();
        return SyncResult(url: '', error: 'Failed to create spreadsheet.');
      }

      final db = DatabaseHelper.instance;

      // Products
      final products = await db.getAllProducts();
      final productHeaders = [
        'barcode', 'name', 'category', 'price', 'cost',
        'quantity', 'unit', 'description', 'date_added', 'date_updated',
      ];
      final productRows = products.map((p) => [
        p.barcode, p.name, p.category, p.price, p.cost,
        p.quantity, p.unit, p.description, p.dateAdded, p.dateUpdated,
      ]).toList();

      await sheets.spreadsheets.values.update(
        ValueRange(
          range: 'Products!A1',
          values: [productHeaders, ...productRows],
        ),
        spreadsheetId,
        'Products!A1',
        valueInputOption: 'USER_ENTERED',
      );

      // Stock Movements
      final movements = await db.getStockMovements();
      final movementHeaders = [
        'id', 'product_id', 'product_name', 'old_quantity',
        'new_quantity', 'delta', 'type', 'date',
      ];
      final movementRows = movements.map((m) => [
        m.id, m.productId, m.productName, m.oldQuantity,
        m.newQuantity, m.delta, m.type, m.date,
      ]).toList();

      await sheets.spreadsheets.values.update(
        ValueRange(
          range: 'Stock Movements!A1',
          values: [movementHeaders, ...movementRows],
        ),
        spreadsheetId,
        'Stock Movements!A1',
        valueInputOption: 'USER_ENTERED',
      );

      // Price Changes
      final priceChanges = await db.getPriceChangeList();
      final priceHeaders = [
        'id', 'product_id', 'product_name', 'old_price',
        'new_price', 'old_cost', 'new_cost', 'date',
      ];
      final priceRows = priceChanges.map((c) => [
        c.id, c.productId, c.productName, c.oldPrice,
        c.newPrice, c.oldCost, c.newCost, c.date,
      ]).toList();

      await sheets.spreadsheets.values.update(
        ValueRange(
          range: 'Price Changes!A1',
          values: [priceHeaders, ...priceRows],
        ),
        spreadsheetId,
        'Price Changes!A1',
        valueInputOption: 'USER_ENTERED',
      );

      // Receipts
      final receipts = await db.getAllReceipts();
      final receiptHeaders = [
        'id', 'receipt_no', 'subtotal', 'tax', 'total',
        'cash', 'change', 'items_count', 'date',
      ];
      final receiptRows = receipts.map((r) => [
        r.id, r.receiptNo, r.subtotal, r.tax, r.total,
        r.cash, r.change, r.items.length, r.date,
      ]).toList();

      await sheets.spreadsheets.values.update(
        ValueRange(
          range: 'Receipts!A1',
          values: [receiptHeaders, ...receiptRows],
        ),
        spreadsheetId,
        'Receipts!A1',
        valueInputOption: 'USER_ENTERED',
      );

      client.close();

      return SyncResult(
        url: 'https://docs.google.com/spreadsheets/d/$spreadsheetId',
        productsSynced: products.length,
        stockMovementsSynced: movements.length,
        priceChangesSynced: priceChanges.length,
        receiptsSynced: receipts.length,
      );
    } catch (e) {
      return SyncResult(url: '', error: 'Sync failed: $e');
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
