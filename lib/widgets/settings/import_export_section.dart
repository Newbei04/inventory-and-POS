import 'dart:io';

import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../utils/export_import_helper.dart';

class ImportExportSection extends StatefulWidget {
  const ImportExportSection({super.key});

  @override
  State<ImportExportSection> createState() => _ImportExportSectionState();
}

class _ImportExportSectionState extends State<ImportExportSection> {
  final _db = DatabaseHelper.instance;
  bool _loading = false;

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
    return Column(
      children: [
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
                  onPressed: _loading ? null : _exportAll,
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download),
                  label: const Text('Export'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
                  onPressed: _loading ? null : _import,
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.file_open),
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
}
