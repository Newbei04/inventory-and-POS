import 'package:flutter/material.dart';

import '../../models/product.dart';

class CartItemRef {
  final Product product;
  final int quantity;
  const CartItemRef({required this.product, required this.quantity});
}

class QtyDialog extends StatefulWidget {
  final Product product;
  final List<CartItemRef> cart;
  const QtyDialog({super.key, required this.product, required this.cart});

  @override
  State<QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<QtyDialog> {
  final _ctrl = TextEditingController(text: '1');
  String? _error;

  int get _inCart {
    final i = widget.cart
        .indexWhere((c) => c.product.id == widget.product.id);
    return i >= 0 ? widget.cart[i].quantity : 0;
  }

  int get _available => widget.product.quantity - _inCart;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = int.tryParse(_ctrl.text.trim());
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter a whole number greater than 0');
      return;
    }
    if (v > _available) {
      setState(
        () => _error = 'Only $_available ${widget.product.unit} available',
      );
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Add ${widget.product.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Text(
            'In cart: $_inCart  •  Available: $_available ${widget.product.unit}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          if (_available <= 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No stock available',
                style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _available > 0 ? _submit : null,
          child: const Text('Add to cart'),
        ),
      ],
    );
  }
}
