import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../db/database_helper.dart';
import '../utils/scan_beep.dart';
import '../widgets/settings/import_export_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper.instance;
  final _storeNameController = TextEditingController();
  String? _storeImagePath;
  bool _savingStore = false;
  String? _storeAddress;
  String? _storePhone;
  String? _defaultScanMode;

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
    final scanMode = await _db.getSetting('default_scan_mode');
    if (mounted) {
      _storeNameController.text = name ?? 'My Store';
      _storeImagePath = image;
      _storeAddress = address ?? '';
      _storePhone = phone ?? '';
      _defaultScanMode = scanMode;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
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
                // ── Import / Export ──
                const ImportExportSection(),
                const SizedBox(height: 16),
                // ── Default Scanner ──
                _card(
                  icon: Icons.qr_code_scanner,
                  title: 'Default Scanner',
                  subtitle: 'Skip the scan method picker',
                  cs: cs,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _defaultScanMode == null
                            ? 'No default set — you choose each time'
                            : 'Default: ${_defaultScanMode == 'camera' ? 'Camera Scanner' : 'USB Scanner'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: _defaultScanMode == null ? Colors.grey.shade600 : Colors.green.shade700,
                          fontWeight: _defaultScanMode != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _db.setSetting('default_scan_mode', 'camera');
                                if (!mounted) return;
                                setState(() => _defaultScanMode = 'camera');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Default set to Camera Scanner')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.qr_code_scanner, size: 18),
                              label: const Text('Camera'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(
                                  color: _defaultScanMode == 'camera' ? Colors.blue : Colors.grey.shade300,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _db.setSetting('default_scan_mode', 'external');
                                if (!mounted) return;
                                setState(() => _defaultScanMode = 'external');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Default set to USB Scanner')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.usb, size: 18),
                              label: const Text('USB'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(
                                  color: _defaultScanMode == 'external' ? Colors.green : Colors.grey.shade300,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _defaultScanMode != null
                                ? () async {
                                    await _db.setSetting('default_scan_mode', '');
                                    if (!mounted) return;
                                    setState(() => _defaultScanMode = null);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Default removed — you will choose each time')),
                                      );
                                    }
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            ),
                            child: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── Scan Sound ──
                _card(
                  icon: Icons.volume_up_outlined,
                  title: 'Scan Sound',
                  subtitle: 'Beep on barcode scan',
                  cs: cs,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Play beep sound on scan'),
                    subtitle: Text(
                      ScanBeep.isEnabled ? 'Enabled' : 'Disabled',
                      style: TextStyle(
                        fontSize: 12,
                        color: ScanBeep.isEnabled ? Colors.green.shade700 : Colors.grey.shade500,
                      ),
                    ),
                    secondary: Icon(
                      ScanBeep.isEnabled ? Icons.volume_up : Icons.volume_off,
                      color: ScanBeep.isEnabled ? Colors.green : Colors.grey,
                    ),
                    value: ScanBeep.isEnabled,
                    onChanged: (v) async {
                      await ScanBeep.setEnabled(v);
                      if (mounted) setState(() {});
                    },
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
