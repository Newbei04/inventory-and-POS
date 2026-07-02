import 'package:flutter/material.dart';

import '../utils/google_sheets_sync.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _syncing = false;
  SyncResult? _result;

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _result = null;
    });

    final result = await GoogleSheetsSync.syncAll();

    if (!mounted) return;
    setState(() {
      _syncing = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Sheets Sync'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _result == null
                    ? Icons.cloud_upload_outlined
                    : _result!.isSuccess
                        ? Icons.cloud_done
                        : Icons.cloud_off,
                size: 72,
                color: _result == null
                    ? Colors.grey.shade400
                    : _result!.isSuccess
                        ? Colors.green
                        : Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                _result == null
                    ? 'Sync to Google Sheets'
                    : _result!.isSuccess
                        ? 'Sync Complete!'
                        : 'Sync Failed',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _result == null
                    ? 'Upload all your products, stock movements,\nprice changes, and receipts to Google Sheets.\n\n'
                      'You\'ll need a Google account to sign in.'
                    : _result!.isSuccess
                        ? 'All your data has been synced to a new spreadsheet.'
                        : _result!.error ?? 'An error occurred.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              if (_result != null && _result!.isSuccess) ...[
                const SizedBox(height: 24),
                _buildSummaryCard(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _result!.url,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _syncing ? null : _sync,
                  icon: _syncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload, size: 24),
                  label: Text(
                    _syncing
                        ? 'Syncing...'
                        : _result != null && _result!.isSuccess
                            ? 'Sync Again'
                            : 'Sync Now',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              if (_result != null && _result!.isSuccess) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await GoogleSheetsSync.signOut();
                      if (mounted) {
                        setState(() => _result = null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Signed out of Google'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow(Icons.inventory_2, 'Products',
                '${_result!.productsSynced}'),
            const Divider(height: 16),
            _summaryRow(Icons.history, 'Stock Movements',
                '${_result!.stockMovementsSynced}'),
            const Divider(height: 16),
            _summaryRow(Icons.trending_up, 'Price Changes',
                '${_result!.priceChangesSynced}'),
            const Divider(height: 16),
            _summaryRow(Icons.receipt_long, 'Receipts',
                '${_result!.receiptsSynced}'),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String count) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 14)),
        ),
        Text(
          count,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
