import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/product.dart';

class ProductDetailDialog extends StatelessWidget {
  final Product product;
  const ProductDetailDialog({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.quantity <= 5;
    final profit = product.price - product.cost;
    final profitMargin = product.cost > 0
        ? ((profit / product.cost) * 100).toStringAsFixed(1)
        : '0.0';

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (product.imagePath.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
              child: Image.file(
                File(product.imagePath),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _detailPlaceholder(isLowStock),
              ),
            )
          else
            _detailPlaceholder(isLowStock),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.category,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.qr_code,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      product.barcode,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _expandedInfo('Price',
                        '₱${product.price.toStringAsFixed(2)}', Colors.blue),
                    Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.shade200),
                    _expandedInfo(
                        'Cost',
                        '₱${product.cost.toStringAsFixed(2)}',
                        Colors.grey.shade700),
                    Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.shade200),
                    _expandedInfo(
                        'Margin',
                        '$profitMargin%',
                        profit >= 0 ? Colors.green : Colors.red),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.inventory_2,
                        size: 16,
                        color: isLowStock
                            ? Colors.red.shade600
                            : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '${product.quantity} ${product.unit}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isLowStock
                            ? Colors.red.shade600
                            : Colors.black87,
                      ),
                    ),
                    if (isLowStock) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Low Stock',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                if (product.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    product.description,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, 'edit'),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, 'delete'),
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: Colors.red.shade400),
                    label: Text('Delete',
                        style:
                            TextStyle(color: Colors.red.shade400)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _expandedInfo(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _detailPlaceholder(bool isLowStock) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isLowStock ? Colors.red.shade50 : Colors.grey.shade100,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Icon(
        Icons.inventory_2,
        size: 64,
        color:
            isLowStock ? Colors.red.shade300 : Colors.grey.shade400,
      ),
    );
  }
}
