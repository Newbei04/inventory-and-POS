import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../db/database_helper.dart';
import '../../models/product.dart';
import 'camera_capture_screen.dart';
import 'scan_screen.dart';

class AddEditProductScreen extends StatefulWidget {
  const AddEditProductScreen({super.key, this.existing, this.prefilledBarcode});

  final Product? existing;
  final String? prefilledBarcode;

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
 

  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _descriptionCtrl;

  String _imagePath = '';
  bool _saving = false;
  String _selectedCategory = 'General';
  List<String> _categories = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _selectedCategory = p?.category ?? 'General';
    _categories = [_selectedCategory]; // ensure dropdown has a value at first build
    _barcodeCtrl = TextEditingController(
      text: p?.barcode ?? widget.prefilledBarcode ?? '',
    );
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _priceCtrl = TextEditingController(
      text: p == null ? '' : p.price.toStringAsFixed(2),
    );
    _costCtrl = TextEditingController(text: p == null ? '' : p.cost.toStringAsFixed(2));
    _quantityCtrl = TextEditingController(
      text: p == null ? '0' : p.quantity.toString(),
    );
    _unitCtrl = TextEditingController(text: p?.unit ?? 'pcs');
    _descriptionCtrl = TextEditingController(text: p?.description ?? '');
    _imagePath = p?.imagePath ?? '';
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper.instance.getCategories();
    final merged = [_selectedCategory,
        ...cats.where((c) => c != _selectedCategory)];
    if (mounted) {
      setState(() => _categories = merged);
    }
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _quantityCtrl.dispose();
    _unitCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _addNewCategory() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Category name',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      setState(() {
        _categories.add(name);
        _selectedCategory = name;
      });
    }
  }

  Future<void> _pickImage() async {
    final useCamera = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select image source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (useCamera == null) return;

    if (useCamera) {
      await _capturePhoto();
      return;
    }

    await _pickFromGallery();
  }

  Future<void> _capturePhoto() async {
    final path = await Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        builder: (_) => const CameraCaptureScreen(),
      ),
    );
    if (path != null && mounted) {
      final saved = await _saveImageToPersistentStorage(path);
      if (mounted) setState(() => _imagePath = saved ?? path);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.single.path != null && mounted) {
        final saved =
            await _saveImageToPersistentStorage(result.files.single.path!);
        if (mounted) setState(() => _imagePath = saved ?? result.files.single.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open gallery: $e')),
        );
      }
    }
  }

  /// Copy [sourcePath] to the app's persistent documents directory so the
  /// image survives cache clears and temp-file deletions. Returns the
  /// persistent path, or `null` if copying failed.
  static Future<String?> _saveImageToPersistentStorage(String sourcePath) async {
    try {
      final dir = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'product_images'),
      );
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final ext = p.extension(sourcePath);
      final dest = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}$ext');
      await File(sourcePath).copy(dest);
      return dest;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _authenticate() async {
    final db = DatabaseHelper.instance;
    final hasPassword = await db.isPasswordSet();

    if (!hasPassword) {
      if (!mounted) return false;
      final pinCtrl = TextEditingController();
      final setupPin = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.pin_outlined, size: 22),
              SizedBox(width: 8),
              Text('Set Edit PIN', style: TextStyle(fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Create a 4-6 digit PIN to protect product edits.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'New PIN',
                  prefixIcon: Icon(Icons.pin_outlined),
                  counterText: '',
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (v) =>
                    Navigator.pop(context, v.trim()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, pinCtrl.text.trim()),
              child: const Text('Set PIN'),
            ),
          ],
        ),
      );
      if (setupPin == null || setupPin.length < 4 || setupPin.length > 6) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Valid PIN (4-6 digits) required')),
          );
        }
        return false;
      }
      await db.setPassword(setupPin);
      return true;
    }

    for (var attempts = 0; attempts < 3; attempts++) {
      if (!mounted) return false;
      final pinCtrl = TextEditingController();
      final input = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.pin_outlined, size: 22),
              SizedBox(width: 8),
              Text('Enter PIN', style: TextStyle(fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${3 - attempts} attempt(s) remaining',
                style: TextStyle(fontSize: 13, color: Colors.red.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: Icon(Icons.pin_outlined),
                  counterText: '',
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (v) =>
                    Navigator.pop(context, v.trim()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, pinCtrl.text.trim()),
              child: const Text('Unlock'),
            ),
          ],
        ),
      );
      if (input == null) return false;
      if (await db.verifyPassword(input)) return true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect PIN')),
        );
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Too many failed attempts')),
      );
    }
    return false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final newQty = int.tryParse(_quantityCtrl.text.trim()) ?? 0;
    final newPrice = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final newCost = double.tryParse(_costCtrl.text.trim()) ?? 0;

    final product = Product(
      id: widget.existing?.id,
      barcode: _barcodeCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      category: _selectedCategory.isEmpty ? 'General' : _selectedCategory,
      price: newPrice,
      cost: newCost,
      quantity: newQty,
      unit: _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      imagePath: _imagePath,
      dateAdded: widget.existing?.dateAdded ?? DateTime.now().toIso8601String(),
      dateUpdated: DateTime.now().toIso8601String(),
    );

    try {
      if (_isEdit && !await _authenticate()) return;

      final db = DatabaseHelper.instance;
      final existing = await db.getProductByBarcode(product.barcode);
      if (existing != null && existing.id != widget.existing?.id) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A product with this barcode already exists.'),
            ),
          );
        }
        return;
      }

      if (_isEdit) {
        final old = await db.getProductById(widget.existing!.id!);
        if (old == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product not found')),
            );
          }
          return;
        }

        if (product.id == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid product ID')),
            );
          }
          return;
        }

        final confirmed = await _showEditConfirmation(old, product);
        if (confirmed != true || !mounted) return;

        await db.updateProduct(product);

        if (old.price != newPrice || old.cost != newCost) {
          await db.logPriceChange(
            productId: product.id!,
            productName: product.name,
            oldPrice: old.price,
            newPrice: newPrice,
            oldCost: old.cost,
            newCost: newCost,
          );
        }

        if (old.quantity != newQty) {
          await db.logStockChange(
            productId: product.id!,
            productName: product.name,
            oldQuantity: old.quantity,
            newQuantity: newQty,
            type: newQty > old.quantity ? 'add' : 'sale',
          );
        }
      } else {
        final id = await db.insertProduct(product);
        product.id = id;
        if (newQty > 0) {
          await db.logStockChange(
            productId: id,
            productName: product.name,
            oldQuantity: 0,
            newQuantity: newQty,
            type: 'add',
          );
        }
      }
      if (mounted) Navigator.of(context).pop(product);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _showEditConfirmation(Product old, Product updated) {
    final changes = <Widget>[];
    void addRow(String label, String oldVal, String newVal) {
      if (oldVal == newVal) return;
      changes.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ),
              Expanded(
                child: Text(oldVal,
                    style: const TextStyle(
                        fontSize: 12, decoration: TextDecoration.lineThrough)),
              ),
              const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
              Expanded(
                child: Text(newVal,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    addRow('Name', old.name, updated.name);
    addRow('Barcode', old.barcode, updated.barcode);
    addRow('Category', old.category, updated.category);
    addRow('Price', '₱${old.price.toStringAsFixed(2)}',
        '₱${updated.price.toStringAsFixed(2)}');
    addRow('Cost', '₱${old.cost.toStringAsFixed(2)}',
        '₱${updated.cost.toStringAsFixed(2)}');
    addRow('Unit', old.unit, updated.unit);
    if (old.quantity != updated.quantity) {
      addRow('Stock', '${old.quantity}', '${updated.quantity}');
    }
    if (old.description != updated.description) {
      addRow('Desc', old.description.isEmpty ? '(empty)' : old.description,
          updated.description.isEmpty ? '(empty)' : updated.description);
    }

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.edit_note, color: Colors.blue.shade700, size: 18),
            ),
            const SizedBox(width: 8),
            const Text('Confirm Changes',
                style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${old.name} will be updated:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            if (changes.isEmpty)
              Text('No changes detected',
                  style: TextStyle(color: Colors.grey.shade500))
            else
              ...changes,
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'This will remove "${widget.existing!.name}" permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && widget.existing?.id != null) {
      await DatabaseHelper.instance.deleteProduct(widget.existing!.id!);
      if (mounted) Navigator.of(context).pop(widget.existing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Product' : 'New Product'),
        centerTitle: true,
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                        image: _imagePath.isNotEmpty
                            ? DecorationImage(
                                image: FileImage(File(_imagePath)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _imagePath.isEmpty
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt,
                                    size: 32, color: Colors.grey),
                                SizedBox(height: 4),
                                Text(
                                  'Add Photo',
                                  style:
                                      TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            )
                          : null,
                    ),
                    if (_imagePath.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _barcodeCtrl,
              decoration: InputDecoration(
                labelText: 'Barcode',
                prefixIcon: const Icon(Icons.qr_code, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final barcode = await ScanScreen.pickAndScan(
                      context,
                      title: 'Scan Barcode',
                    );
                    if (barcode != null && mounted) {
                      _barcodeCtrl.text = barcode;
                    }
                  },
                  tooltip: 'Scan barcode',
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Barcode is required'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Product name',
                prefixIcon: Icon(Icons.label_outline, size: 20),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined, size: 20),
              ),
              items: [
                ...{_selectedCategory, ..._categories}.map(
                  (c) => DropdownMenuItem(value: c, child: Text(c)),
                ),
                const DropdownMenuItem(
                  enabled: false,
                  child: Divider(height: 1),
                ),
                const DropdownMenuItem(
                  value: '__add_new__',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Add new category...'),
                    ],
                  ),
                ),
              ],
              onChanged: (v) async {
                if (v == '__add_new__') {
                  await _addNewCategory();
                  return;
                }
                if (v != null) {
                  setState(() => _selectedCategory = v);
                }
              },
              validator: (v) =>
                  v == null || v.isEmpty ? 'Category required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Selling price',
                      prefixIcon: Icon(Icons.trending_up, size: 20),
                      prefixText: '₱ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final val = double.tryParse(v.trim());
                      if (val == null) return 'Invalid number';
                      if (val <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _costCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cost price',
                      prefixIcon: Icon(Icons.money_off, size: 20),
                      prefixText: '₱ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final val = double.tryParse(v.trim());
                      if (val == null) return 'Invalid number';
                      if (val < 0) return 'Cannot be negative';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityCtrl,
                    decoration: InputDecoration(
                      labelText: _isEdit ? 'Current stock' : 'Quantity',
                      prefixIcon: Icon(Icons.numbers, size: 20),
                      hintText: _isEdit ? 'Use + button in product list to adjust' : null,
                    ),
                    keyboardType: TextInputType.number,
                    readOnly: _isEdit,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final val = int.tryParse(v.trim());
                      if (val == null) return 'Invalid number';
                      if (val < 0) return 'Cannot be negative';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      prefixIcon: Icon(Icons.straighten, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(Icons.description_outlined, size: 20),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEdit ? 'Update Product' : 'Save Product'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
