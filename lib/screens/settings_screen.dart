import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../db/database_helper.dart';
import '../utils/export_import_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper.instance;
  final _storeNameController = TextEditingController();
  String? _storeImagePath;
  bool _loading = false;
  bool _savingStore = false;
  String? _storeAddress;
  String? _storePhone;

  @override
  void initState() {
    super.initState();
    _loadStoreSettings();
  }

  Future<void> _loadStoreSettings() async {
    final name = await _db.getSetting('store_name');
    final image = await _db.getSetting('store_image_path');
    final address = await _db.getSetting('store_address');
    final phone = await _db.getSetting('store_phone');
    if (mounted) {
      _storeNameController.text = name ?? 'My Store';
      _storeImagePath = image;
      _storeAddress = address ?? '';
      _storePhone = phone ?? '';
    }
  }

  Future<void> _pickStoreImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    await _db.setSetting('store_image_path', picked.path);
    setState(() => _storeImagePath = picked.path);
  }

  Future<void> _saveStoreSettings() async {
    setState(() => _savingStore = true);
    try {
      await _db.setSetting('store_name', _storeNameController.text.trim());
      await _db.setSetting('store_address', _storeAddress ?? '');
      await _db.setSetting('store_phone', _storePhone ?? '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store settings saved')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingStore = false);
    }
  }

  // ── Import / Export (moved from ImportExportScreen) ──

  Future<void> _exportAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _db.getAllProducts(),
        _db.getStockMovements(),
        _db.getPriceChangeList(),
      ]);
      final path = await ExportImportHelper.exportCombined(
        products: (results[0] as List).cast(),
        movements: (results[1] as List).cast(),
        changes: (results[2] as List).cast(),
      );
      if (mounted) _showExportSuccess(path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showExportSuccess(String filePath) {
    final fileName = filePath.split(Platform.pathSeparator).last;
    final dirPath = filePath.substring(0, filePath.length - fileName.length - 1);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Export Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved to:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(dirPath, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.blue.shade800)),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Text(fileName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ExportImportHelper.shareFile(filePath, text: 'Exported file');
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    setState(() => _loading = true);
    try {
      final result = await ExportImportHelper.pickAndImport();
      if (result.products.isEmpty && result.stockMovements.isEmpty && result.priceChanges.isEmpty && result.errors.isEmpty) return;

      int imported = 0;
      int updated = 0;
      int skipped = 0;
      int movementsImported = 0;
      int priceChangesImported = 0;
      final importErrors = <String>[];

      for (final product in result.products) {
        try {
          final existing = await _db.getProductByBarcode(product.barcode);
          if (existing == null) {
            final id = await _db.insertProduct(product);
            product.id = id;
            if (product.quantity > 0) {
              await _db.logStockChange(
                productId: id,
                productName: product.name,
                oldQuantity: 0,
                newQuantity: product.quantity,
                type: 'add',
              );
            }
            imported++;
          } else {
            await _db.upsertByBarcode(product);
            updated++;
          }
        } catch (e) {
          skipped++;
          importErrors.add('${product.name} (${product.barcode}): $e');
        }
      }

      for (final movement in result.stockMovements) {
        try {
          await _db.insertStockMovementRaw(movement);
          movementsImported++;
        } catch (e) {
          importErrors.add('Stock movement ${movement.productName}: $e');
        }
      }

      for (final change in result.priceChanges) {
        try {
          await _db.insertPriceChangeRaw(change);
          priceChangesImported++;
        } catch (e) {
          importErrors.add('Price change ${change.productName}: $e');
        }
      }

      if (mounted) _showResultDialog(imported, updated, skipped, movementsImported, priceChangesImported, [...result.errors, ...importErrors]);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final path = await ExportImportHelper.downloadTemplate();
      if (mounted) _showExportSuccess(path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save template: $e')));
    }
  }

  void _showResultDialog(int imported, int updated, int skipped, int movementsImported, int priceChangesImported, List<String> errors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text('$imported products added'),
            ]),
            if (updated > 0) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.edit, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text('$updated products updated'),
              ]),
            ],
            if (movementsImported > 0) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.swap_vert, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                Text('$movementsImported stock movements imported'),
              ]),
            ],
            if (priceChangesImported > 0) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.trending_up, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Text('$priceChangesImported price changes imported'),
              ]),
            ],
            if (skipped > 0) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text('$skipped skipped due to errors'),
              ]),
            ],
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Warnings:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: errors.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(errors[i], style: const TextStyle(fontSize: 12, color: Colors.orange)),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // ── Store Settings ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.store, size: 28, color: cs.primary),
                            const SizedBox(width: 10),
                            Text(
                              'Store Settings',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 38),
                          child: Text(
                            'Displayed on receipts',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: GestureDetector(
                            onTap: _pickStoreImage,
                            child: Stack(
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey.shade100,
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: _storeImagePath != null && File(_storeImagePath!).existsSync()
                                      ? ClipOval(
                                          child: Image.file(
                                            File(_storeImagePath!),
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Icon(Icons.store, size: 40, color: Colors.grey.shade400),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: Icon(Icons.camera_alt, size: 16, color: cs.onPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _storeNameController,
                          decoration: const InputDecoration(
                            labelText: 'Store Name',
                            prefixIcon: Icon(Icons.storefront),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Address (optional)',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            hintText: _storeAddress?.isEmpty ?? true ? 'e.g. 123 Main St, Manila' : null,
                          ),
                          controller: TextEditingController(text: _storeAddress ?? ''),
                          onChanged: (v) => _storeAddress = v,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Phone (optional)',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            hintText: _storePhone?.isEmpty ?? true ? 'e.g. (02) 8123-4567' : null,
                          ),
                          controller: TextEditingController(text: _storePhone ?? ''),
                          onChanged: (v) => _storePhone = v,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _savingStore ? null : _saveStoreSettings,
                            icon: _savingStore
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.save, size: 18),
                            label: const Text('Save Store Settings'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // ── Export ──
                _card(
                  icon: Icons.file_download_outlined,
                  title: 'Export',
                  subtitle: 'Choose data to export',
                  cs: cs,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.folder, size: 20, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ExportImportHelper.getExportsDirPath(),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: () async {
                                final changed = await ExportImportHelper.pickExportDir();
                                if (changed && mounted) setState(() {});
                              },
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text('Change', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _exportAll,
                          icon: const Icon(Icons.download),
                          label: const Text('Export'),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── Import ──
                _card(
                  icon: Icons.file_open,
                  title: 'Import',
                  subtitle: 'Import products from a file',
                  cs: cs,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _import,
                          icon: const Icon(Icons.file_open),
                          label: const Text('Pick File and Import'),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _downloadTemplate,
                          icon: const Icon(Icons.download),
                          label: const Text('Download Template'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme cs,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28, color: cs.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    super.dispose();
  }
}
