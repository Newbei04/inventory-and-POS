import 'package:flutter/material.dart';

import '../db/database_helper.dart';

/// Shows the scanner mode bottom sheet (Camera / USB) matching the
/// Price Checker v1 style.  Returns the selected [ScannerChoice].
///
/// Optionally saves the choice as the app-wide default via [saveAsDefault].
Future<ScannerChoice?> showScannerModeSheet(
  BuildContext context, {
  required bool isExternal,
}) {
  return showModalBottomSheet<ScannerChoice>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ScannerModeSheet(isExternal: isExternal),
  );
}

enum ScannerChoice { camera, external }

class _ScannerModeSheet extends StatefulWidget {
  final bool isExternal;
  const _ScannerModeSheet({required this.isExternal});

  @override
  State<_ScannerModeSheet> createState() => _ScannerModeSheetState();
}

class _ScannerModeSheetState extends State<_ScannerModeSheet> {
  late bool _external;
  bool _saveDefault = false;

  @override
  void initState() {
    super.initState();
    _external = widget.isExternal;
  }

  Future<void> _apply(ScannerChoice choice) async {
    if (_saveDefault) {
      final db = DatabaseHelper.instance;
      await db.setSetting(
        'default_scan_mode',
        choice == ScannerChoice.external ? 'external' : 'camera',
      );
    }
    if (mounted) Navigator.pop(context, choice);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.qr_code_scanner, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 12),
              const Text(
                'Scanner Mode',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ScannerOption(
            icon: Icons.camera_alt,
            title: 'Camera Scanner',
            subtitle: 'Use the device camera to scan barcodes',
            selected: !_external,
            onTap: () {
              setState(() => _external = false);
              _apply(ScannerChoice.camera);
            },
          ),
          const SizedBox(height: 8),
          _ScannerOption(
            icon: Icons.usb,
            title: 'USB Scanner',
            subtitle: 'Use a USB barcode scanner',
            selected: _external,
            onTap: () {
              setState(() => _external = true);
              _apply(ScannerChoice.external);
            },
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _saveDefault,
            onChanged: (v) => setState(() => _saveDefault = v ?? false),
            title: const Text(
              'Set as default',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              'Remember this choice for all screens',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ScannerOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? Colors.blue : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected ? Colors.blue.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.blue.shade700 : Colors.grey.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.blue.shade700 : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: Colors.blue.shade600),
            ],
          ),
        ),
      ),
    );
  }
}
