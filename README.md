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

## Google Sheets Sync

The **Sync** button on the dashboard uploads all local data (products, stock
movements, price changes, receipts) to a new Google Sheets spreadsheet. It
uses the official Google Sheets API v4 via the
[`googleapis`](https://pub.dev/packages/googleapis) package.

### Setup

To enable Google sign-in you must create OAuth 2.0 client IDs for each
platform in the [Google Cloud Console](https://console.cloud.google.com/).

1. **Create a Cloud Project** (or reuse an existing one).

2. **Enable the Google Sheets API:**
   - Go to *APIs & Services → Library*.
   - Search for "Google Sheets API" and click **Enable**.

3. **Configure the OAuth consent screen** (if not already done):
   - *APIs & Services → OAuth consent screen*.
   - Choose **External** (or Internal if you have a Google Workspace org).
   - Required scopes: `.../auth/spreadsheets`.

4. **Create OAuth 2.0 credentials:**

   ### Android
   - Add your app's **package name** (e.g. `com.example.price_checker`) and
     your **SHA-1 signing certificate fingerprint**.
   - The debug fingerprint is obtained with:
     ```bash
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```

   ### iOS
   - Add your app's **bundle identifier** (e.g. `com.example.priceChecker`).
   - If you haven't set one yet, set `PRODUCT_BUNDLE_IDENTIFIER` in
     `ios/Runner.xcodeproj` (or via Xcode) and match it here.

   ### Web (if targeting web)
   - Add your web application's **authorized JavaScript origins** and
     **redirect URIs** (e.g. `http://localhost` for development).

5. **Update platform config files** (many of these steps are automated by the
   Firebase / Google Sign-In Flutter plugin, but you must provide the config):

   - **Android:** Place `google-services.json` (from Firebase console if using
     Firebase, or follow the
     [google_sign_in](https://pub.dev/packages/google_sign_in) plugin docs)
     in `android/app/`.

   - **iOS:** Place `GoogleService-Info.plist` in `ios/Runner/` (also from
     Firebase or the Google Sign-In plugin setup).

   - **Web:** Add your OAuth 2.0 Web client ID to `web/index.html` as a
     `<meta>` tag (see the `google_sign_in_web` docs).

6. **Run `flutter pub get`** — all required packages are already listed in
   `pubspec.yaml`.

After setup, tap **Sync Now** on the Sync screen. The app signs in with the
selected Google account, creates the spreadsheet, and writes all data. You'll
see a link to the new spreadsheet when it's done.

## Extending later

- The database layer (`database_helper.dart`) is isolated, so swapping to a
  synced backend (e.g. hitting your `dar-web` PHP endpoints instead of/along
  with SQLite) later just means adding an API client and calling it
  alongside or instead of the local upserts — the UI layer doesn't need to
  change.
- To add barcode **generation** (e.g. for products without a printed code),
  a package like `barcode` + `pdf` can render printable labels from the
  `Product.barcode` field.