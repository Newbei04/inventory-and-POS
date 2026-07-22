# Future Updates

## Google Sheets Bidirectional Sync

### Goal
Upgrade the existing one-way Google Sheets export into a **bidirectional sync** with a reusable spreadsheet. Products are synced both ways (app ↔ Sheets); transaction tables (stock movements, price changes, receipts) are push-only using per-row sync flags.

---

### Phase 0: Google Cloud Console Setup (Manual)

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Create a new project (e.g. "Price Checker")
3. Enable **Google Sheets API** (APIs & Services → Library → search → Enable)
4. Create **OAuth 2.0 credentials**:
   - Application type: **Android** — package name: `com.example.price_checker`, SHA-1 from your signing key
   - Application type: **iOS** — Bundle ID from your iOS project
5. Download config files:
   - `google-services.json` → place in `android/app/`
   - `GoogleService-Info.plist` → place in `ios/Runner/`

---

### Phase 1: Platform Configuration

| File | Change |
|---|---|
| `android/build.gradle.kts` | Add `classpath("com.google.gms:google-services:4.4.2")` |
| `android/app/build.gradle.kts` | Add `id("com.google.gms.google-services")` plugin |
| `android/app/google-services.json` | Place downloaded file (user action) |
| `ios/Runner/GoogleService-Info.plist` | Place downloaded file (user action) |

---

### Phase 2: Database Changes

#### New Settings Keys (`app_settings` table)

| Key | Purpose |
|---|---|
| `google_spreadsheet_id` | Persisted spreadsheet ID (reuse across syncs) |
| `google_spreadsheet_url` | URL for display/opening |
| `last_sync_at` | Timestamp of last successful sync |
| `google_account_email` | Display which account is connected |
| `sheet_version` | Tracks the spreadsheet schema version for future upgrades |

#### New Columns on Transaction Tables

Add `is_synced` and `synced_at` to **Stock Movements**, **Price Changes**, and **Receipts**:

| Column | Type | Default | Purpose |
|---|---|---|---|
| `is_synced` | INTEGER | `0` | `0` = not yet pushed, `1` = pushed to Sheets |
| `synced_at` | TEXT | `null` | ISO 8601 timestamp of when the row was synced |

These columns enable reliable push-only sync: only rows where `is_synced = 0` are uploaded. After successful upload, each row is marked `is_synced = 1` with `synced_at` set. If a sync is interrupted, unsent rows are never lost — they are retried on the next sync.

---

### Phase 3: Rewrite `lib/utils/google_sheets_sync.dart`

#### Sync Strategy Per Table

| Table | Direction | Matching Key | Sync Mechanism |
|---|---|---|---|
| **Products** | Bidirectional | `barcode` (unique) | `date_updated` for conflict resolution |
| **Stock Movements** | Push only | — | Append rows where `is_synced = 0`, then mark synced |
| **Price Changes** | Push only | — | Append rows where `is_synced = 0`, then mark synced |
| **Receipts** | Push only | — | Append rows where `is_synced = 0`, then mark synced |

#### Product Conflict Resolution (Pull from Sheets)

```
For each row in Google Sheets:
  1. Find local product by barcode
  2. Not found locally → INSERT (new product from Sheets)
  3. Found locally:
     - Sheet date_updated > local date_updated → UPDATE local
     - local date_updated > Sheet date_updated → UPDATE Sheet
     - Equal → skip
```

#### Push-Only Flow (Stock Movements, Price Changes, Receipts)

```
1. Query local DB: SELECT * WHERE is_synced = 0
2. Append those rows to the corresponding Google Sheets tab
3. On success, update each pushed row:
   SET is_synced = 1, synced_at = <current timestamp>
4. If sync fails or is interrupted, rows stay is_synced = 0 and retry next time
```

#### Header Validation

Before syncing, read the header row (row 1) of each sheet and compare against the expected column list. If any sheet has missing or mismatched headers, **stop the sync** and return an error:

```
Expected headers for "Products" sheet:
  barcode, name, category, price, cost, quantity, unit, description,
  date_added, date_updated

If actual headers don't match → return SyncResult with error:
  "Products sheet headers do not match expected format.
   Expected: barcode, name, ...
   Found: barcode, nome, ..."
```

This prevents corrupting or importing from a manually edited or incorrect spreadsheet.

#### Concurrent Sync Prevention

```dart
static bool _isSyncing = false;

static Future<SyncResult> syncAll() async {
  if (_isSyncing) {
    return SyncResult(url: '', error: 'A sync is already in progress.');
  }
  _isSyncing = true;
  try {
    // ... sync logic ...
  } finally {
    _isSyncing = false;
  }
}
```

#### Key Methods

| Method | Purpose |
|---|---|
| `syncAll()` | Full bidirectional sync (guarded by `_isSyncing` flag) |
| `_getOrCreateSpreadsheet()` | Reuse saved spreadsheet ID or create new one |
| `_validateHeaders()` | Verify each sheet has expected column headers |
| `_pushProducts()` | Push local product changes to Sheet |
| `_pullProducts()` | Read Sheet rows, merge into local DB by barcode |
| `_pushMovements()` | Append rows where `is_synced = 0`, then mark synced |
| `_pushPriceChanges()` | Append rows where `is_synced = 0`, then mark synced |
| `_pushReceipts()` | Append rows where `is_synced = 0`, then mark synced |
| `isConnected()` | Check sign-in + spreadsheet ID exists |
| `disconnect()` | Sign out + clear saved spreadsheet ID |

#### Updated SyncResult

```dart
class SyncResult {
  final String url;
  final int productsPushed;
  final int productsPulled;
  final int movementsPushed;
  final int priceChangesPushed;
  final int receiptsPushed;
  final String? error;
  bool get isSuccess => error == null;
}
```

---

### Google Sheets Structure (Sample Sheets)

The spreadsheet is named **"Price Checker — Inventory"** and contains **5 sheets** (4 data + 1 hidden metadata).

#### Sheet 1: Products (Bidirectional)

| barcode | name | category | price | cost | quantity | unit | description | date_added | date_updated |
|---|---|---|---|---|---|---|---|---|---|
| 8901234567890 | Coca-Cola 500ml | Beverages | 25.00 | 18.00 | 120 | pcs | Carbonated drink | 2025-01-15T08:30:00 | 2025-06-20T14:22:00 |
| 4902102123456 | Oishi Prawn Crackers | Snacks | 15.00 | 10.00 | 85 | pcs | | 2025-02-10T09:00:00 | 2025-06-20T14:22:00 |
| 0012345678905 | Tide Powder 1kg | Household | 139.00 | 115.00 | 30 | pcs | Laundry detergent | 2025-03-05T10:15:00 | 2025-06-18T11:00:00 |
| 5449000000996 | Sprite 1.5L | Beverages | 38.00 | 28.00 | 60 | pcs | Lemon-lime soda | 2025-04-01T08:00:00 | 2025-06-20T14:22:00 |

> **Sync notes:**
> - `barcode` is the unique key for matching rows between app and Sheets
> - `date_updated` is used for conflict resolution (newer wins)
> - Editing any cell in Sheets (price, quantity, name, etc.) will pull the change into the app on next sync
> - Adding a new row in Sheets (with a new barcode) will create a new product in the app

#### Sheet 2: Stock Movements (Push Only)

| id | product_id | product_name | old_quantity | new_quantity | delta | type | reason | date | is_synced | synced_at |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | Coca-Cola 500ml | 0 | 120 | 120 | add | Restock | 2025-01-15T08:35:00 | 1 | 2025-01-15T09:00:00 |
| 2 | 2 | Oishi Prawn Crackers | 0 | 85 | 85 | add | Restock | 2025-02-10T09:05:00 | 1 | 2025-02-10T09:30:00 |
| 3 | 1 | Coca-Cola 500ml | 120 | 118 | -2 | sale | | 2025-06-20T10:12:00 | 1 | 2025-06-20T10:15:00 |
| 4 | 3 | Tide Powder 1kg | 32 | 30 | -2 | sale | | 2025-06-20T10:15:00 | 1 | 2025-06-20T10:15:00 |
| 5 | 1 | Coca-Cola 500ml | 118 | 115 | -3 | adjustment | Expired | 2025-06-21T08:00:00 | 0 | |

> **Sync notes:**
> - Push only — only rows where `is_synced = 0` are uploaded
> - After successful upload, `is_synced` is set to `1` and `synced_at` to current timestamp
> - If sync is interrupted, unsent rows remain `is_synced = 0` and retry next time
> - `type` values: `add`, `sale`, `adjustment`, `restock`, `void`, `refund`
> - `reason` is optional context for adjustments

#### Sheet 3: Price Changes (Push Only)

| id | product_id | product_name | old_price | new_price | old_cost | new_cost | date | is_synced | synced_at |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | Coca-Cola 500ml | 0 | 25.00 | 0 | 18.00 | 2025-01-15T08:30:00 | 1 | 2025-01-15T09:00:00 |
| 2 | 2 | Oishi Prawn Crackers | 0 | 15.00 | 0 | 10.00 | 2025-02-10T09:00:00 | 1 | 2025-02-10T09:30:00 |
| 3 | 1 | Coca-Cola 500ml | 25.00 | 28.00 | 18.00 | 20.00 | 2025-06-15T09:30:00 | 0 | |

> **Sync notes:**
> - Push only — only rows where `is_synced = 0` are uploaded
> - After successful upload, `is_synced` is set to `1` and `synced_at` to current timestamp
> - First entry for a product has `old_price` / `old_cost` as 0

#### Sheet 4: Receipts (Push Only)

| id | receipt_no | subtotal | tax | total | cash | change | items_json | is_voided | is_refunded | date | is_synced | synced_at |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | RC-20250620-001 | 50.00 | 6.00 | 56.00 | 100.00 | 44.00 | [{"product_name":"Coca-Cola 500ml","barcode":"8901234567890","price":25.00,"quantity":2,"total":50.00}] | 0 | 0 | 2025-06-20T10:12:00 | 1 | 2025-06-20T10:15:00 |
| 2 | RC-20250620-002 | 139.00 | 16.68 | 155.68 | 200.00 | 44.32 | [{"product_name":"Tide Powder 1kg","barcode":"0012345678905","price":139.00,"quantity":1,"total":139.00}] | 0 | 0 | 2025-06-20T10:15:00 | 0 | |

> **Sync notes:**
> - Push only — only rows where `is_synced = 0` are uploaded
> - After successful upload, `is_synced` is set to `1` and `synced_at` to current timestamp
> - `items_json` contains the full item list for detailed reporting in Sheets
> - `is_voided` / `is_refunded` are `0` or `1` (boolean as integer)

#### Sheet 5: _SYSTEM (Hidden Metadata)

This sheet is hidden from the user and stores sync metadata for future upgrades.

| key | value |
|---|---|
| version | 1 |
| created_at | 2025-06-20T14:22:00 |
| last_sync | 2025-06-21T08:00:00 |
| app_version | 1.0.0 |
| schema_products | barcode, name, category, price, cost, quantity, unit, description, date_added, date_updated |
| schema_movements | id, product_id, product_name, old_quantity, new_quantity, delta, type, reason, date, is_synced, synced_at |
| schema_price_changes | id, product_id, product_name, old_price, new_price, old_cost, new_cost, date, is_synced, synced_at |
| schema_receipts | id, receipt_no, subtotal, tax, total, cash, change, items_json, is_voided, is_refunded, date, is_synced, synced_at |

> **Notes:**
> - `version` allows future code to detect and migrate old spreadsheet formats
> - `schema_*` keys store expected headers so the app can self-validate
> - This sheet is created once during first sync and updated on each subsequent sync

---

### Phase 4: Update `lib/screens/sync_screen.dart`

- Show connection status (account email, spreadsheet link)
- **"Connect to Google"** button (first-time setup)
- **"Sync Now"** button (triggers bidirectional sync, disabled while syncing)
- **"Disconnect"** button (sign out + clear spreadsheet ID)
- Sync summary with push/pull counts per table
- **"Open in Sheets"** link button
- Last sync timestamp display
- Error display for header mismatches or interrupted syncs

---

### Phase 5: Wire into Navigation

| File | Change |
|---|---|
| `lib/screens/settings_screen.dart` | Add "Google Sheets Sync" section → navigates to SyncScreen |
| `lib/screens/dashboard_screen.dart` | Optional: sync status indicator in hero card |

---

### No New Dependencies

Already in `pubspec.yaml`: `google_sign_in`, `googleapis`, `extension_google_sign_in_as_googleapis_auth`.

---

### Implementation Order

1. Google Cloud Console setup (manual browser steps)
2. Android/iOS platform config (Gradle + config files)
3. Database migration — add `is_synced`, `synced_at` columns to transaction tables
4. Rewrite `google_sheets_sync.dart` (core bidirectional logic + header validation + concurrency guard + _SYSTEM sheet)
5. Update `sync_screen.dart` (UI)
6. Wire into settings navigation
7. Test bidirectional sync


PROMPT
# Future Update: Integrate Google Sheets + Google Forms Sync into Existing Flutter App

## Overview

The Flutter application is already fully developed. This update focuses **only on integrating Google Sheets and Google Forms synchronization** into the existing application.

Do **not** redesign, replace, or modify the current application architecture unless required for the synchronization feature.

The goal is to extend the existing inventory system with Google integration while keeping SQLite as the application's primary local database.

Google Sheets will serve as a cloud-accessible inventory spreadsheet, while Google Forms will provide a safe and structured way for users to submit inventory operations such as stock adjustments, price changes, and new product creation.

All synchronization must work seamlessly with the current database, models, repositories, services, and UI already implemented in the application.

## Objectives

* Integrate Google Sign-In into the existing Flutter application.
* Connect to Google Sheets using the authenticated account.
* Reuse a single spreadsheet for future synchronizations.
* Synchronize products between SQLite and Google Sheets.
* Process Google Form responses and apply changes to the local database.
* Automatically generate stock movement and price history records whenever inventory or pricing changes are processed.
* Keep SQLite as the single source of truth while using Google Sheets as a synchronized cloud copy and Google Forms as controlled input for remote updates.

## Important Requirements

* Do not recreate existing screens, models, repositories, or database tables unless necessary.
* Reuse the current SQLite schema and existing CRUD operations wherever possible.
* Integrate the synchronization feature into the existing project structure.
* Only add the files, methods, settings, and UI necessary for Google synchronization.
* Preserve all existing application functionality.
* Ensure all new synchronization logic is modular, maintainable, and consistent with the current codebase.
