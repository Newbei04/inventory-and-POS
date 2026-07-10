import 'dart:io';

import 'package:flutter/material.dart';

import '../db/database_helper.dart';

class StoreReceiptHeader extends StatelessWidget {
  final bool showAddress;

  const StoreReceiptHeader({super.key, this.showAddress = true});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String?>>(
      future: Future.wait([
        DatabaseHelper.instance.getSetting('store_name'),
        DatabaseHelper.instance.getSetting('store_image_path'),
        DatabaseHelper.instance.getSetting('store_address'),
        DatabaseHelper.instance.getSetting('store_phone'),
      ]),
      builder: (context, snapshot) {
        final storeName = snapshot.data?[0] ?? 'My Store';
        final storeImage = snapshot.data?[1];
        final storeAddress = snapshot.data?[2] ?? '';
        final storePhone = snapshot.data?[3] ?? '';

        return Column(
          children: [
            if (storeImage != null && storeImage.isNotEmpty && File(storeImage).existsSync())
              ClipOval(
                child: Image.file(
                  File(storeImage),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              )
            else
              Icon(Icons.store_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              storeName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 1.5,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (showAddress) ...[
              const SizedBox(height: 2),
              if (storeAddress.isNotEmpty)
                Text(storeAddress, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              if (storePhone.isNotEmpty)
                Text('Tel: $storePhone', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ],
        );
      },
    );
  }
}
