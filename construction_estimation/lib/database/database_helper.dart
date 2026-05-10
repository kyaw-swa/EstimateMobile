import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'seed_data.dart';

/// Singleton database helper.
///
/// Schema versioning: bump [_dbVersion] နဲ့ [_onUpgrade] မှာ migration ထည့်
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _dbName = 'construction_estimation.db';

  /// Schema version. Bump and add a branch to [_onUpgrade] when changing schema.
  ///
  /// History:
  /// - v1: initial (had `code`/`description`/`unit_price` on master tables — wrong).
  /// - v2: align UoM/Material/Labour with Odoo: `uom_type` on UoM,
  ///       `default_rate` (renamed from `unit_price`) + UNIQUE name on Material/Labour.
  /// - v3: full BoQ default seed (14 UoMs + 51 Materials + 8 Labour) replaces
  ///       v2's UoM-only Odoo seed. Triggers full rebuild for v1/v2 devices.
  /// - v4: align AbstractOfCost tables with Odoo: parent gets
  ///       `base_quantity`/`base_uom_id`/`measurement_type`; lines rename
  ///       `unit_price` → `rate`; UNIQUE(ac_id, material_id/labour_id) added.
  /// - v5: align ProjectEstimate tables with Odoo: parent loses `code`/
  ///       `location`, `client_name` → `customer_name`; estimate_line gains
  ///       dimensions/measurement_type/manual_qty; line_material/labour
  ///       gain template_qty/template_base_qty/is_manual/per.
  static const int _dbVersion = 5;

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<String> get databasePath async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, _dbName);
  }

  Future<Database> _initDatabase() async {
    final path = await databasePath;
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Foreign key support ဖွင့်
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    _createUomTable(batch);
    _createMaterialTable(batch);
    _createLabourTable(batch);
    _createAbstractOfCostTables(batch);
    _createProjectEstimateTables(batch);
    await batch.commit(noResult: true);

    await SeedData.seedAll(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Dev-stage policy: any version < current → full rebuild. Acceptable
    // because we have no production users; both v1 (wrong schema) and v2
    // (Odoo-only UoM seed) need their seed data refreshed for v3.
    if (oldVersion < 5) {
      await _rebuildAll(db);
    }
  }

  /// Drop and recreate all tables, then re-run the default seed.
  ///
  /// Destructive — wipes ALL master and transaction data. Used by upgrade
  /// migrations during the dev stage when schema or seed data changes
  /// significantly.
  ///
  /// Drops in reverse FK-dependency order so children release references
  /// before parents disappear.
  Future<void> _rebuildAll(Database db) async {
    final batch = db.batch();
    // Children first (FK dependents)
    batch.execute('DROP TABLE IF EXISTS construction_estimate_line_material');
    batch.execute('DROP TABLE IF EXISTS construction_estimate_line_labour');
    batch.execute('DROP TABLE IF EXISTS construction_estimate_line');
    batch.execute('DROP TABLE IF EXISTS construction_project_estimate');
    batch.execute('DROP TABLE IF EXISTS construction_ac_material');
    batch.execute('DROP TABLE IF EXISTS construction_ac_labour');
    batch.execute('DROP TABLE IF EXISTS construction_ac');
    batch.execute('DROP TABLE IF EXISTS construction_material');
    batch.execute('DROP TABLE IF EXISTS construction_labour');
    batch.execute('DROP TABLE IF EXISTS construction_uom');

    _createUomTable(batch);
    _createMaterialTable(batch);
    _createLabourTable(batch);
    _createAbstractOfCostTables(batch);
    _createProjectEstimateTables(batch);
    await batch.commit(noResult: true);

    await SeedData.seedAll(db);
  }

  // ───────────── Schema ─────────────

  void _createUomTable(Batch batch) {
    // Mirrors Odoo construction.uom: name, uom_type (material/labour/both), active.
    batch.execute('''
      CREATE TABLE construction_uom (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL UNIQUE,
        uom_type    TEXT NOT NULL DEFAULT 'both'
                    CHECK (uom_type IN ('material', 'labour', 'both')),
        active      INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');
  }

  void _createMaterialTable(Batch batch) {
    // Mirrors Odoo construction.material: name (UNIQUE), uom_id, default_rate, active.
    batch.execute('''
      CREATE TABLE construction_material (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT NOT NULL UNIQUE,
        uom_id        INTEGER,
        default_rate  REAL NOT NULL DEFAULT 0,
        active        INTEGER NOT NULL DEFAULT 1,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL,
        FOREIGN KEY (uom_id) REFERENCES construction_uom(id) ON DELETE SET NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_material_uom ON construction_material(uom_id)',
    );
    batch.execute(
      'CREATE INDEX idx_material_name ON construction_material(name)',
    );
  }

  void _createLabourTable(Batch batch) {
    // Mirrors Odoo construction.labour: name (UNIQUE), uom_id, default_rate, active.
    batch.execute('''
      CREATE TABLE construction_labour (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT NOT NULL UNIQUE,
        uom_id        INTEGER,
        default_rate  REAL NOT NULL DEFAULT 0,
        active        INTEGER NOT NULL DEFAULT 1,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL,
        FOREIGN KEY (uom_id) REFERENCES construction_uom(id) ON DELETE SET NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_labour_uom ON construction_labour(uom_id)',
    );
    batch.execute(
      'CREATE INDEX idx_labour_name ON construction_labour(name)',
    );
  }

  void _createAbstractOfCostTables(Batch batch) {
    // Mirrors Odoo construction.ac: name (indexed), description, active,
    // base_quantity, base_uom_id, measurement_type [sqft/cuft].
    batch.execute('''
      CREATE TABLE construction_ac (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        name              TEXT NOT NULL,
        description       TEXT,
        base_quantity     REAL NOT NULL DEFAULT 1,
        base_uom_id       INTEGER,
        measurement_type  TEXT NOT NULL DEFAULT 'sqft'
                          CHECK (measurement_type IN ('sqft', 'cuft')),
        active            INTEGER NOT NULL DEFAULT 1,
        created_at        TEXT NOT NULL,
        updated_at        TEXT NOT NULL,
        FOREIGN KEY (base_uom_id) REFERENCES construction_uom(id) ON DELETE SET NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_ac_name ON construction_ac(name)');

    // Material lines — Odoo: ac_id, material_id, sequence, quantity, rate,
    // UNIQUE(ac_id, material_id). uom_id and line_cost are derived (not stored).
    batch.execute('''
      CREATE TABLE construction_ac_material (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        ac_id         INTEGER NOT NULL,
        material_id   INTEGER NOT NULL,
        sequence      INTEGER NOT NULL DEFAULT 10,
        quantity      REAL NOT NULL DEFAULT 1,
        rate          REAL NOT NULL DEFAULT 0,
        UNIQUE (ac_id, material_id),
        FOREIGN KEY (ac_id) REFERENCES construction_ac(id) ON DELETE CASCADE,
        FOREIGN KEY (material_id) REFERENCES construction_material(id) ON DELETE RESTRICT
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_ac_material_ac ON construction_ac_material(ac_id)',
    );

    // Labour lines — same pattern.
    batch.execute('''
      CREATE TABLE construction_ac_labour (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        ac_id         INTEGER NOT NULL,
        labour_id     INTEGER NOT NULL,
        sequence      INTEGER NOT NULL DEFAULT 10,
        quantity      REAL NOT NULL DEFAULT 1,
        rate          REAL NOT NULL DEFAULT 0,
        UNIQUE (ac_id, labour_id),
        FOREIGN KEY (ac_id) REFERENCES construction_ac(id) ON DELETE CASCADE,
        FOREIGN KEY (labour_id) REFERENCES construction_labour(id) ON DELETE RESTRICT
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_ac_labour_ac ON construction_ac_labour(ac_id)',
    );
  }

  void _createProjectEstimateTables(Batch batch) {
    // Mirrors Odoo construction.project.estimate. `customer_name` replaces
    // Odoo's `customer_id` Many2one(res.partner) — single-user app has no
    // partner registry. Computed totals (material/labour/grand) are derived
    // on read, not stored.
    batch.execute('''
      CREATE TABLE construction_project_estimate (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        name            TEXT NOT NULL,
        customer_name   TEXT,
        date            TEXT,
        state           TEXT NOT NULL DEFAULT 'draft'
                        CHECK (state IN ('draft', 'confirmed', 'cancelled')),
        notes           TEXT,
        created_at      TEXT NOT NULL,
        updated_at      TEXT NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_estimate_state ON construction_project_estimate(state)',
    );

    // Mirrors Odoo construction.estimate.line. Stores dimension inputs
    // (length/breadth/height in ft + in) and `manual_qty`. Derived fields
    // (area, volume, base_qty, totals) are computed in Dart, not stored.
    // `measurement_type` is denormalized from ac_id (Odoo: related store).
    batch.execute('''
      CREATE TABLE construction_estimate_line (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        estimate_id       INTEGER NOT NULL,
        ac_id             INTEGER NOT NULL,
        sequence          INTEGER NOT NULL DEFAULT 10,
        reference         TEXT,
        measurement_type  TEXT NOT NULL DEFAULT 'sqft'
                          CHECK (measurement_type IN ('sqft', 'cuft')),
        uom_id            INTEGER,
        length_ft         REAL NOT NULL DEFAULT 0,
        length_in         REAL NOT NULL DEFAULT 0,
        breadth_ft        REAL NOT NULL DEFAULT 0,
        breadth_in        REAL NOT NULL DEFAULT 0,
        height_ft         REAL NOT NULL DEFAULT 0,
        height_in         REAL NOT NULL DEFAULT 0,
        manual_qty        REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (estimate_id)
          REFERENCES construction_project_estimate(id) ON DELETE CASCADE,
        FOREIGN KEY (ac_id) REFERENCES construction_ac(id) ON DELETE RESTRICT,
        FOREIGN KEY (uom_id) REFERENCES construction_uom(id) ON DELETE SET NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_estimate_line_estimate '
      'ON construction_estimate_line(estimate_id)',
    );

    // Material detail rows — copied from ac.material_line_ids on AC selection,
    // then per-row overridable. `template_qty` × ratio gives suggested_qty
    // (computed); `is_manual` locks `quantity` against recompute.
    batch.execute('''
      CREATE TABLE construction_estimate_line_material (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        line_id             INTEGER NOT NULL,
        material_id         INTEGER NOT NULL,
        sequence            INTEGER NOT NULL DEFAULT 10,
        reference           TEXT,
        template_qty        REAL NOT NULL DEFAULT 0,
        template_base_qty   REAL NOT NULL DEFAULT 1,
        is_manual           INTEGER NOT NULL DEFAULT 0,
        quantity            REAL NOT NULL DEFAULT 0,
        rate                REAL NOT NULL DEFAULT 0,
        per                 REAL NOT NULL DEFAULT 1,
        FOREIGN KEY (line_id)
          REFERENCES construction_estimate_line(id) ON DELETE CASCADE,
        FOREIGN KEY (material_id)
          REFERENCES construction_material(id) ON DELETE RESTRICT
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_eline_material_line '
      'ON construction_estimate_line_material(line_id)',
    );

    // Labour detail rows — same pattern as material.
    batch.execute('''
      CREATE TABLE construction_estimate_line_labour (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        line_id             INTEGER NOT NULL,
        labour_id           INTEGER NOT NULL,
        sequence            INTEGER NOT NULL DEFAULT 10,
        reference           TEXT,
        template_qty        REAL NOT NULL DEFAULT 0,
        template_base_qty   REAL NOT NULL DEFAULT 1,
        is_manual           INTEGER NOT NULL DEFAULT 0,
        quantity            REAL NOT NULL DEFAULT 0,
        rate                REAL NOT NULL DEFAULT 0,
        per                 REAL NOT NULL DEFAULT 1,
        FOREIGN KEY (line_id)
          REFERENCES construction_estimate_line(id) ON DELETE CASCADE,
        FOREIGN KEY (labour_id)
          REFERENCES construction_labour(id) ON DELETE RESTRICT
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_eline_labour_line '
      'ON construction_estimate_line_labour(line_id)',
    );
  }

  /// Public: run all default seeds (UoMs, Materials, Labour) safely on an
  /// existing database. Each seed is idempotent — skips its target table
  /// if it already has rows. Use to populate an empty/partial DB without
  /// affecting existing user data.
  Future<void> ensureDefaultData() async {
    final db = await database;
    await SeedData.seedAll(db);
  }

  /// Destructive: delete the entire database file and recreate it from
  /// schema + seed. Use with confirmation — wipes ALL user data.
  Future<void> deleteAndRecreate() async {
    final path = await databasePath;
    await close();
    await deleteDatabase(path);
    _database = null;
    await database;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
