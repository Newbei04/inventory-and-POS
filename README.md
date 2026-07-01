# Inventory Scanner (Flutter)

Barcode inventory app: scan a barcode → look up the product and show its
price ("price checker"), or add it as new if it doesn't exist yet. All data
is stored locally on-device (SQLite). Export/import via JSON, CSV, or Excel.

## What's included

```
lib/
  main.dart
  models/product.dart
  db/database_helper.dart          # SQLite (sqflite)
  utils/export_import_helper.dart  # JSON / CSV / Excel export+import
  screens/home_screen.dart         # inventory list, search, scan FAB
  screens/scan_screen.dart         # camera barcode scanner
  screens/add_edit_product_screen.dart
  screens/import_export_screen.dart
  widgets/product_card.dart
  widgets/price_check_sheet.dart   # big price display on scan match
pubspec.yaml
```

## Setup (run these on your machine — Flutter SDK isn't available here)

1. **Create the Flutter project shell** (generates `android/`, `ios/`, etc.):
   ```bash
   flutter create inventory_scanner
   ```

2. **Copy these files in**, overwriting the generated `lib/` and `pubspec.yaml`:
   - Copy this `lib/` folder over the generated one.
   - Copy this `pubspec.yaml` over the generated one.

3. **Install dependencies:**
   ```bash
   cd inventory_scanner
   flutter pub get
   ```

4. **Add permissions** (required for camera scanning and file access):

   ### Android — `android/app/src/main/AndroidManifest.xml`
   Add inside `<manifest>`, before `<application>`:
   ```xml
    
   <uses-feature android:name="android.hardware.camera" android:required="true" />
   ```
   Also set `minSdkVersion` to at least 21 in `android/app/build.gradle`
   (`android { defaultConfig { minSdkVersion 21 ... } }`) — required by
   `mobile_scanner`.

   ### iOS — `ios/Runner/Info.plist`
   Add inside the outer `<dict>`:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Camera access is needed to scan product barcodes.</string>
   ```

5. **Run it:**
   ```bash
   flutter run
   ```

## How it works

- **Scan flow:** tap *Scan* → camera opens → on a successful read, the app
  looks up the barcode in the local SQLite database.
  - **Found:** a bottom sheet shows the product name and a large price,
    plus stock level, with quick actions to *Edit* or *Adjust Stock*
    (+/- quantity, e.g. after a sale or restock).
  - **Not found:** you're taken straight to the *New Product* form with the
    barcode pre-filled — fill in name/price/quantity and save.
  - A **manual entry** button on the scan screen covers barcodes the camera
    can't read.

- **Import/Export** (tap the icon in the top app bar):
  - Export writes a file to the app's documents folder and opens the native
    share sheet (save to Drive, email it, AirDrop, etc.).
  - Import opens the file picker; matching is by `barcode` — existing
    barcodes get updated, new ones get inserted.
  - Expected columns/keys for all three formats:
    `barcode, name, category, price, cost, quantity, unit, description, date_added, date_updated`
    (only `barcode` and `name` are strictly required; the rest default
    sensibly if missing).

## Extending later

- The database layer (`database_helper.dart`) is isolated, so swapping to a
  synced backend (e.g. hitting your `dar-web` PHP endpoints instead of/along
  with SQLite) later just means adding an API client and calling it
  alongside or instead of the local upserts — the UI layer doesn't need to
  change.
- To add barcode **generation** (e.g. for products without a printed code),
  a package like `barcode` + `pdf` can render printable labels from the
  `Product.barcode` field.