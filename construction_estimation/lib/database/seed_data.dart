// AUTO-GENERATED from Two_storeyed.xlsx (BQ sheet)
// Do NOT edit by hand — re-run seed extraction script if data changes
//
// Source: Bill of Quantity sheet
// Materials: 51 items, Labours: 8 items, Units: 14
//
// NOTE: Schema-aligned with Odoo construction_estimation:
//   - construction.uom: name (UNIQUE) + uom_type [material/labour/both]
//   - construction.material / labour: name (UNIQUE) + uom_id + default_rate
//
// UoM short codes (`Bags`, `Cwt`, `Suds`, etc.) are stored as `name` to match
// the Odoo data XML defaults. Materials/Labours reference UoMs via name lookup
// since the schema has no `code` column.

import 'package:sqflite/sqflite.dart';

/// Seed master data (UoMs, Materials, Labour) into the database.
///
/// Idempotent: each seeder skips if its target table is already populated.
/// Safe to call on every app start, fresh install, or migration.
class SeedData {
  SeedData._();

  /// Run all seeds in correct dependency order (UoMs → Materials → Labour).
  static Future<void> seedAll(DatabaseExecutor db) async {
    await _seedUoms(db);
    await _seedMaterials(db);
    await _seedLabours(db);
  }

  // ──────────────── Units of Measure ────────────────
  //
  // `uom_type` follows Odoo's construction_uom_data.xml classification:
  //   material → only used for materials
  //   labour   → only used for labour
  //   both     → can be used for either

  static const List<({String name, String uomType})> _uoms = [
    (name: 'Bags', uomType: 'material'),
    (name: 'Cwt', uomType: 'material'),
    (name: 'Doz', uomType: 'material'),
    (name: 'Gal', uomType: 'material'),
    (name: 'Lbs', uomType: 'material'),
    (name: 'Nos', uomType: 'both'),
    (name: 'Pck', uomType: 'material'),
    (name: 'Rft', uomType: 'both'),
    (name: 'Set', uomType: 'material'),
    (name: 'Sft', uomType: 'both'),
    (name: 'Sht', uomType: 'material'),
    (name: 'Suds', uomType: 'material'),
    (name: 'Ton', uomType: 'material'),
    (name: 'Viss', uomType: 'material'),
  ];

  static Future<void> _seedUoms(DatabaseExecutor db) async {
    final existing = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM construction_uom'),
    ) ?? 0;
    if (existing > 0) return;

    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final u in _uoms) {
      batch.insert('construction_uom', {
        'name': u.name,
        'uom_type': u.uomType,
        'active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  // ──────────────── Materials ────────────────
  //
  // `uomName` references construction_uom.name — resolved at insert time.

  static const List<({String name, String uomName})> _materials = [
    (name: 'Jungle wood', uomName: 'Ton'),
    (name: '6"x9" Stone', uomName: 'Suds'),
    (name: 'Cement', uomName: 'Bags'),
    (name: 'Sand', uomName: 'Suds'),
    (name: 'Chipping', uomName: 'Suds'),
    (name: 'Brick', uomName: 'Nos'),
    (name: 'Fuel', uomName: 'Gal'),
    (name: '5 Plywood', uomName: 'Sht'),
    (name: '16mmɸ M.S Rod', uomName: 'Ton'),
    (name: '10mmɸ M.S Rod', uomName: 'Ton'),
    (name: '8mmɸ M.S Rod', uomName: 'Ton'),
    (name: 'Binding wire', uomName: 'Cwt'),
    (name: '1\'-4" Lx1/4" thk post strut', uomName: 'Nos'),
    (name: '1.5" L 5/8ɸ  bolt& nut', uomName: 'Nos'),
    (name: '5"x2" U', uomName: 'Nos'),
    (name: 'Welding rod', uomName: 'Pck'),
    (name: '4"x2" U', uomName: 'Nos'),
    (name: '3"x1⅟2" channel', uomName: 'Nos'),
    (name: '2"x2" angle', uomName: 'Rft'),
    (name: 'Four angle sheet', uomName: 'Rft'),
    (name: 'Roofing nail', uomName: 'Viss'),
    (name: 'Colour plain sheet', uomName: 'Rft'),
    (name: '8"x1" Plank', uomName: 'Ton'),
    (name: 'earth oil', uomName: 'Sft'),
    (name: 'X-met', uomName: 'Rft'),
    (name: '5"x2" Chowket', uomName: 'Rft'),
    (name: 'Chowket M.S bracket', uomName: 'Nos'),
    (name: 'Ready made teak door', uomName: 'Sft'),
    (name: 'Nails', uomName: 'Viss'),
    (name: '5" butt hinge', uomName: 'Nos'),
    (name: '6" tower bolt', uomName: 'Nos'),
    (name: '6" hook & eye', uomName: 'Nos'),
    (name: 'Aluminium Slide lock', uomName: 'Nos'),
    (name: 'Teak', uomName: 'Ton'),
    (name: '3mm Glass', uomName: 'Sft'),
    (name: 'Putty', uomName: 'Gal'),
    (name: 'Sand paper', uomName: 'Doz'),
    (name: 'Putty trowel', uomName: 'Nos'),
    (name: 'Emulsion paint', uomName: 'Gal'),
    (name: 'Paint roller', uomName: 'Nos'),
    (name: 'Ready mixed oil paint', uomName: 'Gal'),
    (name: 'Putty(D)', uomName: 'Lbs'),
    (name: 'Enamel Paint (Gal)', uomName: 'Gal'),
    (name: '3" Paint Brush', uomName: 'Nos'),
    (name: 'Bamboo', uomName: 'Nos'),
    (name: 'Coil yarn', uomName: 'Viss'),
    (name: 'Blackboard', uomName: 'Nos'),
    (name: '8"x8" concrete block', uomName: 'Nos'),
    (name: 'G.I plain sheet', uomName: 'Rft'),
    (name: 'Bracket', uomName: 'Nos'),
    (name: 'Earthing Rod', uomName: 'Set'),
    (name: 'Drain Cover', uomName: 'Nos'),
  ];

  static Future<void> _seedMaterials(DatabaseExecutor db) async {
    final existing = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM construction_material'),
    ) ?? 0;
    if (existing > 0) return;

    final uomMap = await _loadUomMap(db);
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final m in _materials) {
      batch.insert('construction_material', {
        'name': m.name,
        'uom_id': uomMap[m.uomName],
        'default_rate': 0.0, // user fills in later
        'active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  // ──────────────── Labour ────────────────

  static const List<({String name, String uomName})> _labours = [
    (name: 'Masons', uomName: 'Nos'),
    (name: 'Carpenters', uomName: 'Nos'),
    (name: 'Workers', uomName: 'Nos'),
    (name: 'Painters', uomName: 'Nos'),
    (name: 'Mixer Driver', uomName: 'Nos'),
    (name: 'Steel fixer', uomName: 'Nos'),
    (name: 'Surveyor', uomName: 'Nos'),
    (name: 'Smith', uomName: 'Nos'),
  ];

  static Future<void> _seedLabours(DatabaseExecutor db) async {
    final existing = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM construction_labour'),
    ) ?? 0;
    if (existing > 0) return;

    final uomMap = await _loadUomMap(db);
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final l in _labours) {
      batch.insert('construction_labour', {
        'name': l.name,
        'uom_id': uomMap[l.uomName],
        'default_rate': 0.0,
        'active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  // ──────────────── Helpers ────────────────

  /// Map UoM name → id, for resolving Many2one references during seed.
  static Future<Map<String, int>> _loadUomMap(DatabaseExecutor db) async {
    final rows = await db.query('construction_uom', columns: ['id', 'name']);
    return {
      for (final r in rows) r['name'] as String: r['id'] as int,
    };
  }
}
