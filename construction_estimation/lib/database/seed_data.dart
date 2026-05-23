// AUTO-GENERATED from Odoo construction_estimation data XMLs.
//
// Source files (read-only reference):
//   construction_estimation/data/construction_uom_data.xml
//   construction_estimation/data/construction_material_data.xml
//   construction_estimation/data/construction_labour_data.xml
//   construction_estimation/data/construction_ac_data.xml
//
// Schema-aligned with Odoo:
//   - construction.uom:      name (UNIQUE) + uom_type [material/labour/both]
//   - construction.material: name (UNIQUE) + uom_id + default_rate
//   - construction.labour:   name (UNIQUE) + uom_id + default_rate
//   - construction.ac:       name + base_quantity + base_uom_id + measurement_type
//                            + material_line_ids + labour_line_ids
//
// UoM names (e.g. `Bags`, `Sft`, `Cuft`) are stored as `name` to match the
// Odoo data XML. Materials/Labours/ACs resolve UoM via name lookup since
// the schema has no `code` column.

import 'package:sqflite/sqflite.dart';

/// Seed master + template data (UoMs, Materials, Labour, Abstracts of Cost).
///
/// Idempotent: each seeder skips if its target table is already populated.
/// Safe to call on every app start, fresh install, or migration rebuild.
class SeedData {
  SeedData._();

  /// Run all seeds in dependency order (UoM → Material → Labour → AC).
  static Future<void> seedAll(DatabaseExecutor db) async {
    await _seedUoms(db);
    await _seedMaterials(db);
    await _seedLabours(db);
    await _seedAcs(db);
  }

  // ──────────────── Units of Measure ────────────────

  static const List<({String name, String uomType})> _uoms = [
    (name: 'Bags', uomType: 'material'),
    (name: 'Cuft', uomType: 'both'),
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

  static const List<({String name, String uomName, num defaultRate})>
      _materials = [
    (name: 'Jungle wood', uomName: 'Ton', defaultRate: 800000),
    (name: '6"x9" Stone', uomName: 'Suds', defaultRate: 30000),
    (name: 'Cement', uomName: 'Bags', defaultRate: 5900),
    (name: 'Sand', uomName: 'Suds', defaultRate: 12000),
    (name: 'Chipping', uomName: 'Suds', defaultRate: 58000),
    (name: 'Brick', uomName: 'Nos', defaultRate: 100),
    (name: 'Fuel', uomName: 'Gal', defaultRate: 4500),
    (name: '5 Plywood', uomName: 'Sht', defaultRate: 17500),
    (name: '16mmɸ M.S Rod', uomName: 'Ton', defaultRate: 870000),
    (name: '10mmɸ M.S Rod', uomName: 'Ton', defaultRate: 870000),
    (name: '8mmɸ M.S Rod', uomName: 'Ton', defaultRate: 1000000),
    (name: 'Binding wire', uomName: 'Cwt', defaultRate: 80000),
    (name: '1\'-4" Lx1/4" thk post strut', uomName: 'Nos', defaultRate: 3600),
    (name: '1.5" L 5/8ɸ  bolt& nut', uomName: 'Nos', defaultRate: 1500),
    (name: '5"x2" U', uomName: 'Nos', defaultRate: 45000),
    (name: 'Welding rod', uomName: 'Pck', defaultRate: 8000),
    (name: '4"x2" U', uomName: 'Nos', defaultRate: 23500),
    (name: '3"x1⅟2" channel', uomName: 'Nos', defaultRate: 13500),
    (name: '2"x2" angle', uomName: 'Rft', defaultRate: 400),
    (name: 'Four angle sheet', uomName: 'Rft', defaultRate: 1200),
    (name: 'Roofing nail', uomName: 'Viss', defaultRate: 4500),
    (name: 'Colour plain sheet', uomName: 'Rft', defaultRate: 1200),
    (name: '8"x1" Plank', uomName: 'Ton', defaultRate: 800000),
    (name: 'earth oil', uomName: 'Sft', defaultRate: 150),
    (name: 'X-met', uomName: 'Rft', defaultRate: 40),
    (name: '5"x2" Chowket', uomName: 'Rft', defaultRate: 2900),
    (name: 'Chowket M.S bracket', uomName: 'Nos', defaultRate: 300),
    (name: 'Ready made teak door', uomName: 'Sft', defaultRate: 8000),
    (name: 'Nails', uomName: 'Viss', defaultRate: 3000),
    (name: '5" butt hinge', uomName: 'Nos', defaultRate: 700),
    (name: '6" tower bolt', uomName: 'Nos', defaultRate: 900),
    (name: '6" hook & eye', uomName: 'Nos', defaultRate: 800),
    (name: 'Aluminium Slide lock', uomName: 'Nos', defaultRate: 5500),
    (name: 'Teak', uomName: 'Ton', defaultRate: 800000),
    (name: '3mm Glass', uomName: 'Sft', defaultRate: 1500),
    (name: 'Putty', uomName: 'Gal', defaultRate: 10000),
    (name: 'Sand paper', uomName: 'Doz', defaultRate: 1600),
    (name: 'Putty trowel', uomName: 'Nos', defaultRate: 500),
    (name: 'Emulsion paint', uomName: 'Gal', defaultRate: 16000),
    (name: 'Paint roller', uomName: 'Nos', defaultRate: 1600),
    (name: 'Ready mixed oil paint', uomName: 'Gal', defaultRate: 21000),
    (name: 'Putty(D)', uomName: 'Lbs', defaultRate: 600),
    (name: 'Enamel Paint (Gal)', uomName: 'Gal', defaultRate: 9000),
    (name: '3" Paint Brush', uomName: 'Nos', defaultRate: 500),
    (name: 'Bamboo', uomName: 'Nos', defaultRate: 550),
    (name: 'Coil yarn', uomName: 'Viss', defaultRate: 4500),
    (name: 'Blackboard', uomName: 'Nos', defaultRate: 50000),
    (name: '8"x8" concrete block', uomName: 'Nos', defaultRate: 800),
    (name: 'G.I plain sheet', uomName: 'Rft', defaultRate: 900),
    (name: 'Bracket', uomName: 'Nos', defaultRate: 350),
    (name: 'Earthing Rod', uomName: 'Set', defaultRate: 800000),
    (name: 'Drain Cover', uomName: 'Nos', defaultRate: 10000),
    // M+L composites — used by AC 22/23/24/31.
    (name: 'Aluminium W (M+L)', uomName: 'Sft', defaultRate: 6500),
    (name: 'Ceiling with C-channel frame(M+L)', uomName: 'Sft', defaultRate: 1100),
    (name: 'Ceiling with hollow frame(M+L)', uomName: 'Sft', defaultRate: 1300),
    (name: 'Handrail (M+L)', uomName: 'Sft', defaultRate: 4500),
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
        'default_rate': m.defaultRate,
        'active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  // ──────────────── Labour ────────────────

  static const List<({String name, String uomName, num defaultRate})>
      _labours = [
    (name: 'Masons', uomName: 'Nos', defaultRate: 12000),
    (name: 'Carpenters', uomName: 'Nos', defaultRate: 12000),
    (name: 'Workers', uomName: 'Nos', defaultRate: 8000),
    (name: 'Painters', uomName: 'Nos', defaultRate: 12000),
    (name: 'Mixer Driver', uomName: 'Nos', defaultRate: 8000),
    (name: 'Steel fixer', uomName: 'Nos', defaultRate: 12000),
    (name: 'Surveyor', uomName: 'Nos', defaultRate: 12000),
    (name: 'Smith', uomName: 'Nos', defaultRate: 12000),
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
        'default_rate': l.defaultRate,
        'active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  // ──────────────── Abstracts of Cost ────────────────

  static Future<void> _seedAcs(DatabaseExecutor db) async {
    final existing = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM construction_ac'),
    ) ?? 0;
    if (existing > 0) return;

    final uomMap = await _loadUomMap(db);
    final matMap = await _loadMaterialMap(db);
    final labMap = await _loadLabourMap(db);
    final now = DateTime.now().toIso8601String();

    // AC 001
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Site Clearing Leveling and dressing the constructional site to make suitable for the layout',
      baseUomName: 'Sft', measurementType: 'sqft',
      labLines: [(labour: 'Workers', sequence: 10, quantity: 0.25, rate: 8000)],
    );
    // AC 002
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Staking work for preparation of foundation',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Jungle wood', sequence: 10, quantity: 0.006, rate: 800000),
        (material: 'Nails', sequence: 20, quantity: 0.020833, rate: 3000),
      ],
      labLines: [
        (labour: 'Carpenters', sequence: 10, quantity: 0.05, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 0.1, rate: 8000),
        (labour: 'Surveyor', sequence: 30, quantity: 0.01, rate: 12000),
      ],
    );
    // AC 003
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Earth Work in Excavation for foundation in medium soil',
      baseUomName: 'Cuft', measurementType: 'cuft',
      labLines: [(labour: 'Workers', sequence: 10, quantity: 1.999985, rate: 8000)],
    );
    // AC 004
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Hard Core Filling Work',
      baseUomName: 'Cuft', measurementType: 'cuft',
      matLines: [
        (material: '6"x9" Stone', sequence: 10, quantity: 1.000296, rate: 30000),
      ],
      labLines: [(labour: 'Workers', sequence: 10, quantity: 1.000296, rate: 8000)],
    );
    // AC 005
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: '1:3:6 lean concrete work',
      baseUomName: 'Cuft', measurementType: 'cuft',
      matLines: [
        (material: 'Cement', sequence: 10, quantity: 12.857143, rate: 5900),
        (material: 'Sand', sequence: 20, quantity: 0.479837, rate: 12000),
        (material: 'Chipping', sequence: 30, quantity: 0.960171, rate: 58000),
        (material: 'Fuel', sequence: 40, quantity: 1.999901, rate: 4500),
      ],
      labLines: [
        (labour: 'Masons', sequence: 10, quantity: 0.99995, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 6.000199, rate: 8000),
        (labour: 'Mixer Driver', sequence: 30, quantity: 0.500224, rate: 8000),
      ],
    );
    // AC 006
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Brick work in 1:3 Cement Motor',
      baseUomName: 'Cuft', measurementType: 'cuft',
      matLines: [
        (material: 'Brick', sequence: 10, quantity: 1350.002502, rate: 100),
        (material: 'Cement', sequence: 20, quantity: 6.964147, rate: 5900),
        (material: 'Sand', sequence: 30, quantity: 0.260202, rate: 12000),
      ],
      labLines: [
        (labour: 'Masons', sequence: 10, quantity: 3.999975, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 6.000275, rate: 8000),
      ],
    );
    // AC 007
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: '1: 2: 4 R-C Concrete Work',
      baseUomName: 'Cuft', measurementType: 'cuft',
      matLines: [
        (material: 'Cement', sequence: 10, quantity: 18.482097, rate: 5900),
        (material: 'Sand', sequence: 20, quantity: 0.460011, rate: 12000),
        (material: 'Chipping', sequence: 30, quantity: 0.920022, rate: 58000),
        (material: 'Fuel', sequence: 40, quantity: 1.999976, rate: 4500),
      ],
      labLines: [
        (labour: 'Masons', sequence: 10, quantity: 1.999976, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 5.999929, rate: 8000),
        (labour: 'Mixer Driver', sequence: 30, quantity: 0.500031, rate: 8000),
      ],
    );
    // AC 008
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Formwork With Jungne Wood Scantling & 5-Plywood',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Jungle wood', sequence: 10, quantity: 0.199983, rate: 800000),
        (material: '5 Plywood', sequence: 20, quantity: 1.796874, rate: 17500),
        (material: 'Nails', sequence: 30, quantity: 0.833323, rate: 3000),
      ],
      labLines: [
        (labour: 'Carpenters', sequence: 10, quantity: 5.999976, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 2.000012, rate: 8000),
      ],
    );
    // AC 009
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Steel Reinforcement Cut, Bend & Fix',
      baseUomName: 'Ton', measurementType: 'sqft',
      matLines: [
        (material: '16mmɸ M.S Rod', sequence: 10, quantity: 67.73309, rate: 870000),
        (material: '10mmɸ M.S Rod', sequence: 20, quantity: 26.173065, rate: 870000),
        (material: '8mmɸ M.S Rod', sequence: 30, quantity: 5.088361, rate: 1000000),
        (material: 'Binding wire', sequence: 40, quantity: 17.001828, rate: 80000),
      ],
      labLines: [
        (labour: 'Steel fixer', sequence: 10, quantity: 1428.305911, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 1428.305911, rate: 8000),
      ],
    );
    // AC 010
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Sanding filling including watering & ramming for sub-flooring',
      baseUomName: 'Cuft', measurementType: 'cuft',
      matLines: [
        (material: 'Sand', sequence: 10, quantity: 1.250019, rate: 12000),
      ],
      labLines: [(labour: 'Workers', sequence: 10, quantity: 0.999912, rate: 8000)],
    );
    // AC 011
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Earth filling including watering & ramming for sub-flooring',
      baseUomName: 'Cuft', measurementType: 'cuft',
      labLines: [(labour: 'Workers', sequence: 10, quantity: 1.0001, rate: 8000)],
    );
    // AC 012
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Post Strut fitting At top column',
      baseUomName: 'Nos', measurementType: 'sqft',
      matLines: [
        (material: '1\'-4" Lx1/4" thk post strut', sequence: 10, quantity: 100, rate: 3600),
        (material: '1.5" L 5/8ɸ  bolt& nut', sequence: 20, quantity: 100, rate: 1500),
      ],
      labLines: [(labour: 'Steel fixer', sequence: 10, quantity: 25, rate: 12000)],
    );
    // AC 013
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Steel Truss Work',
      baseUomName: 'Ton', measurementType: 'sqft',
      matLines: [
        (material: '5"x2" U', sequence: 10, quantity: 665.978435, rate: 45000),
        (material: '4"x2" U', sequence: 20, quantity: 2678.568521, rate: 23500),
        (material: '3"x1⅟2" channel', sequence: 30, quantity: 4037.880984, rate: 13500),
        (material: '2"x2" angle', sequence: 40, quantity: 2035.386414, rate: 400),
        (material: 'Welding rod', sequence: 50, quantity: 50.151921, rate: 8000),
      ],
      labLines: [
        (labour: 'Smith', sequence: 10, quantity: 4999.886018, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 4000.104212, rate: 8000),
      ],
    );
    // AC 014
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: '4-Angle Sheet Roofing Work',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Four angle sheet', sequence: 10, quantity: 23.310036, rate: 1200),
        (material: 'Roofing nail', sequence: 20, quantity: 0.416594, rate: 4500),
      ],
      labLines: [
        (labour: 'Carpenters', sequence: 10, quantity: 1.500039, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 0.999976, rate: 8000),
      ],
    );
    // AC 015
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Colour Sheet Ridging work',
      baseUomName: 'Rft', measurementType: 'sqft',
      matLines: [
        (material: 'Colour plain sheet', sequence: 10, quantity: 111.998582, rate: 1200),
        (material: 'Roofing nail', sequence: 20, quantity: 1.49919, rate: 4500),
      ],
      labLines: [(labour: 'Carpenters', sequence: 10, quantity: 3.327593, rate: 12000)],
    );
    // AC 016
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Providing and fixing of 8"x1" Pyingado Eave board work',
      baseUomName: 'Rft', measurementType: 'sqft',
      matLines: [
        (material: '8"x1" Plank', sequence: 10, quantity: 0.1388, rate: 800000),
        (material: 'Nails', sequence: 20, quantity: 0.555556, rate: 3000),
        (material: 'earth oil', sequence: 30, quantity: 150, rate: 150),
      ],
      labLines: [(labour: 'Carpenters', sequence: 10, quantity: 3, rate: 12000)],
    );
    // AC 017
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: '4⅟2" thk:Brick Wall in (1:3) Cement Mortar',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Brick', sequence: 10, quantity: 549.999928, rate: 100),
        (material: 'Cement', sequence: 20, quantity: 2.651837, rate: 5900),
        (material: 'Sand', sequence: 30, quantity: 0.100045, rate: 12000),
        (material: 'X-met', sequence: 40, quantity: 115.000051, rate: 40),
      ],
      labLines: [
        (labour: 'Masons', sequence: 10, quantity: 2.000026, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 3.000039, rate: 8000),
      ],
    );
    // AC 018
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Finishing & Laying Smooth ⅟2" thk: (1:3) cement mortor',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Cement', sequence: 10, quantity: 1.339317, rate: 5900),
        (material: 'Sand', sequence: 20, quantity: 0.049996, rate: 12000),
      ],
      labLines: [
        (labour: 'Masons', sequence: 10, quantity: 0.999987, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 1.999973, rate: 8000),
      ],
    );
    // AC 019
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Providing & fixing of  Wood Chowket',
      baseUomName: 'Rft', measurementType: 'sqft',
      matLines: [
        (material: '5"x2" Chowket', sequence: 10, quantity: 100, rate: 2900),
        (material: 'Chowket M.S bracket', sequence: 20, quantity: 23.382697, rate: 300),
        (material: 'X-met', sequence: 30, quantity: 105.000487, rate: 40),
        (material: 'Nails', sequence: 40, quantity: 0.555339, rate: 3000),
      ],
      labLines: [(labour: 'Carpenters', sequence: 10, quantity: 6.500877, rate: 12000)],
    );
    // AC 020
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Supplying and Installation of Readymade Teak Panel',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Ready made teak door', sequence: 10, quantity: 100, rate: 8000),
        (material: '5" butt hinge', sequence: 20, quantity: 14.285714, rate: 700),
        (material: '6" tower bolt', sequence: 30, quantity: 3.571429, rate: 900),
        (material: '6" hook & eye', sequence: 40, quantity: 3.571429, rate: 800),
        (material: 'Aluminium Slide lock', sequence: 50, quantity: 3.571429, rate: 5500),
      ],
      labLines: [(labour: 'Carpenters', sequence: 10, quantity: 19.046875, rate: 12000)],
    );
    // AC 021
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Making & Fixing of Glazed wall complete frame by Chowket',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Teak', sequence: 10, quantity: 0.191831, rate: 800000),
        (material: '3mm Glass', sequence: 20, quantity: 58.332667, rate: 1500),
        (material: 'Nails', sequence: 30, quantity: 0.57949, rate: 3000),
      ],
      labLines: [(labour: 'Carpenters', sequence: 10, quantity: 25.001998, rate: 12000)],
    );
    // AC 022
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Making & Fixing of Window by Aluminium frame',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Aluminium W (M+L)', sequence: 10, quantity: 100, rate: 6500),
      ],
    );
    // AC 023
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: '(a)2\'x2\'Cement Board Ceiling with 2"x1" &1"x1" C-channel frame',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Ceiling with C-channel frame(M+L)', sequence: 10, quantity: 100, rate: 1100),
      ],
    );
    // AC 024
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: '(b)2\'x2\'Cement Board Ceiling with 1"x1" Hollow frame',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Ceiling with hollow frame(M+L)', sequence: 10, quantity: 100, rate: 1300),
      ],
    );
    // AC 025
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: '1.5 thk 1:2:4 concrete floor Topping',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Cement', sequence: 10, quantity: 2.31248, rate: 5900),
        (material: 'Sand', sequence: 20, quantity: 0.057542, rate: 12000),
        (material: 'Chipping', sequence: 30, quantity: 0.114959, rate: 58000),
      ],
      labLines: [
        (labour: 'Masons', sequence: 10, quantity: 0.75003, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 1.499999, rate: 8000),
      ],
    );
    // AC 026
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Surface Preparation Before Painting with Putty (3-Coats)',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Putty', sequence: 10, quantity: 0.75, rate: 10000),
        (material: 'Sand paper', sequence: 20, quantity: 0.500027, rate: 1600),
        (material: 'Putty trowel', sequence: 30, quantity: 0.24998, rate: 500),
      ],
      labLines: [
        (labour: 'Painters', sequence: 10, quantity: 0.999987, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 0.999987, rate: 8000),
      ],
    );
    // AC 027
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Painting 3 Coats with Plastic Emulsion Paint of Any Approved Colour',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Emulsion paint', sequence: 10, quantity: 0.999987, rate: 16000),
        (material: 'Paint roller', sequence: 20, quantity: 0.24998, rate: 1600),
      ],
      labLines: [(labour: 'Painters', sequence: 10, quantity: 0.999987, rate: 12000)],
    );
    // AC 028
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Painting with Readymady Mixed Oil Paint of Any Approves Colour on wooden structure',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Ready mixed oil paint', sequence: 10, quantity: 0.735099, rate: 21000),
        (material: 'Putty(D)', sequence: 20, quantity: 0.039039, rate: 600),
      ],
      labLines: [
        (labour: 'Painters', sequence: 10, quantity: 1.250083, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 1.000066, rate: 8000),
      ],
    );
    // AC 029
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Painting Work MS Member',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Enamel Paint (Gal)', sequence: 10, quantity: 0.735359, rate: 9000),
        (material: '3" Paint Brush', sequence: 20, quantity: 0.299946, rate: 500),
      ],
      labLines: [
        (labour: 'Painters', sequence: 10, quantity: 1.25001, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 1.000088, rate: 8000),
      ],
    );
    // AC 030
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Internal &External Bamboo Scaffolding Work With Necessary Plastering &Painting',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Bamboo', sequence: 10, quantity: 4.861111, rate: 550),
        (material: 'Coil yarn', sequence: 20, quantity: 0.347222, rate: 4500),
        (material: 'Nails', sequence: 30, quantity: 0.144662, rate: 3000),
      ],
      labLines: [(labour: 'Workers', sequence: 10, quantity: 0.520806, rate: 8000)],
    );
    // AC 031
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Making and fixing of Stainless steel handrail',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Handrail (M+L)', sequence: 10, quantity: 100, rate: 4500),
      ],
    );
    // AC 032
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Making and fixing of Blackboard',
      baseUomName: 'Nos', measurementType: 'sqft',
      matLines: [
        (material: 'Blackboard', sequence: 10, quantity: 100, rate: 50000),
      ],
    );
    // AC 033
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Making and fixing of concrete block',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: '8"x8" concrete block', sequence: 10, quantity: 150.000426, rate: 800),
        (material: 'Cement', sequence: 20, quantity: 0.178978, rate: 5900),
      ],
      labLines: [
        (labour: 'Masons', sequence: 10, quantity: 3.99717, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 6.000017, rate: 8000),
      ],
    );
    // AC 034
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Providing and fixing of Gutter work',
      baseUomName: 'Rft', measurementType: 'sqft',
      matLines: [
        (material: 'G.I plain sheet', sequence: 10, quantity: 112, rate: 900),
        (material: 'Roofing nail', sequence: 20, quantity: 0.694444, rate: 4500),
        (material: 'Bracket', sequence: 30, quantity: 33.611111, rate: 350),
      ],
      labLines: [
        (labour: 'Carpenters', sequence: 10, quantity: 5, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 1.5, rate: 8000),
      ],
    );
    // AC 035
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Earth excavation for drain',
      baseUomName: 'Cuft', measurementType: 'cuft',
      labLines: [(labour: 'Workers', sequence: 10, quantity: 1.999755, rate: 8000)],
    );
    // AC 036
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: '1:3:6 cement concrete under drain',
      baseUomName: 'Cuft', measurementType: 'cuft',
      matLines: [
        (material: 'Cement', sequence: 10, quantity: 12.858016, rate: 5900),
        (material: 'Sand', sequence: 20, quantity: 0.479707, rate: 12000),
        (material: 'Chipping', sequence: 30, quantity: 0.959413, rate: 58000),
        (material: 'Fuel', sequence: 40, quantity: 1.998777, rate: 4500),
      ],
      labLines: [
        (labour: 'Masons', sequence: 10, quantity: 1.00174, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 6.001035, rate: 8000),
        (labour: 'Mixer Driver', sequence: 30, quantity: 0.498519, rate: 8000),
      ],
    );
    // AC 037
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: '4.5thk brick work with 1:3 cement mortor for drain',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Brick', sequence: 10, quantity: 550.000533, rate: 100),
        (material: 'Cement', sequence: 20, quantity: 2.652158, rate: 5900),
        (material: 'Sand', sequence: 30, quantity: 0.100283, rate: 12000),
      ],
      labLines: [
        (labour: 'Masons', sequence: 10, quantity: 2.00032, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 2.999947, rate: 8000),
      ],
    );
    // AC 038
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: '1/2" Thick plastering with 1:3 cement mortor for drain',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Cement', sequence: 10, quantity: 1.339272, rate: 5900),
        (material: 'Sand', sequence: 20, quantity: 0.050166, rate: 12000),
      ],
      labLines: [
        (labour: 'Masons', sequence: 10, quantity: 1.000274, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 1.999787, rate: 8000),
      ],
    );
    // AC 039
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Sand filling under apron',
      baseUomName: 'Cuft', measurementType: 'cuft',
      matLines: [
        (material: 'Sand', sequence: 10, quantity: 1.252209, rate: 12000),
      ],
      labLines: [(labour: 'Workers', sequence: 10, quantity: 0.999748, rate: 8000)],
    );
    // AC 040
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: '1:3:6 cement concrete work for apron',
      baseUomName: 'Cuft', measurementType: 'cuft',
      matLines: [
        (material: 'Cement', sequence: 10, quantity: 12.860713, rate: 5900),
        (material: 'Sand', sequence: 20, quantity: 0.477164, rate: 12000),
        (material: 'Chipping', sequence: 30, quantity: 0.961903, rate: 58000),
        (material: 'Fuel', sequence: 40, quantity: 1.999546, rate: 4500),
      ],
      labLines: [
        (labour: 'Masons', sequence: 10, quantity: 0.999773, rate: 12000),
        (labour: 'Workers', sequence: 20, quantity: 5.998637, rate: 8000),
        (labour: 'Mixer Driver', sequence: 30, quantity: 0.499886, rate: 8000),
      ],
    );
    // AC 041
    await _insertAc(db, now, uomMap, matMap, labMap,
      name: 'Drain Cover Work',
      baseUomName: 'Sft', measurementType: 'sqft',
      matLines: [
        (material: 'Drain Cover', sequence: 10, quantity: 100, rate: 10000),
      ],
    );
  }

  /// Insert one AC parent + its lines in dependency order.
  ///
  /// All ACs in the Odoo seed use base_quantity=100, so it's a default here.
  /// `matLines` / `labLines` resolve material/labour names against the
  /// preloaded master maps — unmapped names will surface as a NOT NULL
  /// constraint violation, flagging missing seed entries.
  static Future<void> _insertAc(
    DatabaseExecutor db,
    String now,
    Map<String, int> uomMap,
    Map<String, int> matMap,
    Map<String, int> labMap, {
    required String name,
    required String baseUomName,
    required String measurementType,
    num baseQuantity = 100,
    List<({String material, int sequence, num quantity, num rate})> matLines =
        const [],
    List<({String labour, int sequence, num quantity, num rate})> labLines =
        const [],
  }) async {
    final acId = await db.insert('construction_ac', {
      'name': name,
      'base_quantity': baseQuantity,
      'base_uom_id': uomMap[baseUomName],
      'measurement_type': measurementType,
      'active': 1,
      'created_at': now,
      'updated_at': now,
    });

    if (matLines.isEmpty && labLines.isEmpty) return;

    final batch = db.batch();
    for (final l in matLines) {
      batch.insert('construction_ac_material', {
        'ac_id': acId,
        'material_id': matMap[l.material],
        'sequence': l.sequence,
        'quantity': _round6(l.quantity),
        'rate': l.rate,
      });
    }
    for (final l in labLines) {
      batch.insert('construction_ac_labour', {
        'ac_id': acId,
        'labour_id': labMap[l.labour],
        'sequence': l.sequence,
        'quantity': _round6(l.quantity),
        'rate': l.rate,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Round AC line standard quantity to 6 decimal places.
  ///
  /// Odoo source XML carries quantities at varying precision (e.g.
  /// `0.020833`, `1428.305911`); normalising to 6dp on insert keeps the
  /// stored values consistent with what `Float(16, 4..6)` Odoo fields would
  /// produce and avoids long IEEE-754 trailing-digit drift in the UI.
  static num _round6(num value) =>
      double.parse(value.toStringAsFixed(6));

  // ──────────────── Helpers ────────────────

  /// Map UoM name → id, for resolving Many2one references during seed.
  static Future<Map<String, int>> _loadUomMap(DatabaseExecutor db) async {
    final rows = await db.query('construction_uom', columns: ['id', 'name']);
    return {for (final r in rows) r['name'] as String: r['id'] as int};
  }

  static Future<Map<String, int>> _loadMaterialMap(DatabaseExecutor db) async {
    final rows =
        await db.query('construction_material', columns: ['id', 'name']);
    return {for (final r in rows) r['name'] as String: r['id'] as int};
  }

  static Future<Map<String, int>> _loadLabourMap(DatabaseExecutor db) async {
    final rows = await db.query('construction_labour', columns: ['id', 'name']);
    return {for (final r in rows) r['name'] as String: r['id'] as int};
  }
}
