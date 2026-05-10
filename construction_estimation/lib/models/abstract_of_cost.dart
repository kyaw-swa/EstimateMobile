/// Mirror of Odoo `construction.ac` (Abstract of Cost) and its line models.
///
/// **Parent — `construction.ac`:**
/// - name              Char, required, indexed
/// - description       Text
/// - active            Boolean, default True
/// - base_quantity     Float(16, 4), default 1.0
/// - base_uom_id       Many2one('construction.uom')
/// - measurement_type  Selection [sqft/cuft], default 'sqft', required
/// - material_line_ids One2many → construction.ac.material
/// - labour_line_ids   One2many → construction.ac.labour
///
/// **Lines — `construction.ac.material` / `construction.ac.labour`:**
/// - ac_id        Many2one('construction.ac'), cascade
/// - material_id / labour_id  Many2one, restrict
/// - sequence     Integer, default 10
/// - quantity     Float(16, 4), default 1.0  (std qty per parent.base_quantity)
/// - rate         Float(16, 4)               (defaults from material/labour.default_rate)
/// - UNIQUE(ac_id, material_id) / UNIQUE(ac_id, labour_id)
///
/// Computed fields are derived in Dart, not stored:
/// - line.lineCost = quantity * rate
/// - parent.materialCost / labourCost / totalCost = sum(lineCost)
library;

/// Odoo `measurement_type` selection — describes whether the AC is
/// measured in area (Sqft) or volume (Cuft).
enum MeasurementType {
  sqft('sqft', 'Sqft (Area)'),
  cuft('cuft', 'Cuft (Volume)');

  const MeasurementType(this.value, this.label);

  final String value;
  final String label;

  static MeasurementType fromValue(String? raw) {
    return MeasurementType.values.firstWhere(
      (t) => t.value == raw,
      orElse: () => MeasurementType.sqft,
    );
  }
}

class AbstractOfCost {
  AbstractOfCost({
    this.id,
    required this.name,
    this.description,
    this.baseQuantity = 1.0,
    this.baseUomId,
    this.baseUomName,
    this.measurementType = MeasurementType.sqft,
    this.active = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AcMaterialLine>? materialLines,
    List<AcLabourLine>? labourLines,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        materialLines = materialLines ?? const [],
        labourLines = labourLines ?? const [];

  final int? id;
  final String name;
  final String? description;
  final double baseQuantity;
  final int? baseUomId;

  /// Display label for the linked base UoM. Populated via JOIN; not stored.
  final String? baseUomName;

  final MeasurementType measurementType;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  final List<AcMaterialLine> materialLines;
  final List<AcLabourLine> labourLines;

  /// Sum of all material line costs (qty * rate).
  double get materialCost =>
      materialLines.fold(0, (sum, l) => sum + l.lineCost);

  /// Sum of all labour line costs.
  double get labourCost => labourLines.fold(0, (sum, l) => sum + l.lineCost);

  /// Combined total — what one Base Quantity of this AC costs.
  double get totalCost => materialCost + labourCost;

  AbstractOfCost copyWith({
    int? id,
    String? name,
    String? description,
    bool clearDescription = false,
    double? baseQuantity,
    int? baseUomId,
    bool clearBaseUomId = false,
    String? baseUomName,
    MeasurementType? measurementType,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AcMaterialLine>? materialLines,
    List<AcLabourLine>? labourLines,
  }) {
    return AbstractOfCost(
      id: id ?? this.id,
      name: name ?? this.name,
      description:
          clearDescription ? null : (description ?? this.description),
      baseQuantity: baseQuantity ?? this.baseQuantity,
      baseUomId: clearBaseUomId ? null : (baseUomId ?? this.baseUomId),
      baseUomName: clearBaseUomId ? null : (baseUomName ?? this.baseUomName),
      measurementType: measurementType ?? this.measurementType,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      materialLines: materialLines ?? this.materialLines,
      labourLines: labourLines ?? this.labourLines,
    );
  }

  /// Persistable parent fields only. Lines persist via their own toMap.
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'base_quantity': baseQuantity,
      'base_uom_id': baseUomId,
      'measurement_type': measurementType.value,
      'active': active ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// [map] may include `base_uom_name` from a JOIN. Lines must be loaded
  /// separately (see `AbstractOfCostRepository`).
  factory AbstractOfCost.fromMap(
    Map<String, Object?> map, {
    List<AcMaterialLine> materialLines = const [],
    List<AcLabourLine> labourLines = const [],
  }) {
    return AbstractOfCost(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      baseQuantity: (map['base_quantity'] as num?)?.toDouble() ?? 1.0,
      baseUomId: map['base_uom_id'] as int?,
      baseUomName: map['base_uom_name'] as String?,
      measurementType:
          MeasurementType.fromValue(map['measurement_type'] as String?),
      active: (map['active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      materialLines: materialLines,
      labourLines: labourLines,
    );
  }
}

/// `construction.ac.material` — one material reservation per AC.
class AcMaterialLine {
  AcMaterialLine({
    this.id,
    this.acId,
    required this.materialId,
    this.materialName,
    this.uomName,
    this.sequence = 10,
    this.quantity = 1.0,
    this.rate = 0.0,
  });

  final int? id;

  /// Set on the parent's save path. Null while building lines pre-save.
  final int? acId;

  final int materialId;

  /// Display label for material. Populated via JOIN.
  final String? materialName;

  /// Display label for material's UoM (related field in Odoo). Populated via JOIN.
  final String? uomName;

  final int sequence;
  final double quantity;
  final double rate;

  /// Computed: quantity * rate.
  double get lineCost => quantity * rate;

  AcMaterialLine copyWith({
    int? id,
    int? acId,
    int? materialId,
    String? materialName,
    String? uomName,
    int? sequence,
    double? quantity,
    double? rate,
  }) {
    return AcMaterialLine(
      id: id ?? this.id,
      acId: acId ?? this.acId,
      materialId: materialId ?? this.materialId,
      materialName: materialName ?? this.materialName,
      uomName: uomName ?? this.uomName,
      sequence: sequence ?? this.sequence,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'ac_id': acId,
      'material_id': materialId,
      'sequence': sequence,
      'quantity': quantity,
      'rate': rate,
    };
  }

  factory AcMaterialLine.fromMap(Map<String, Object?> map) {
    return AcMaterialLine(
      id: map['id'] as int?,
      acId: map['ac_id'] as int?,
      materialId: map['material_id'] as int,
      materialName: map['material_name'] as String?,
      uomName: map['uom_name'] as String?,
      sequence: map['sequence'] as int? ?? 10,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      rate: (map['rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// `construction.ac.labour` — one labour reservation per AC.
class AcLabourLine {
  AcLabourLine({
    this.id,
    this.acId,
    required this.labourId,
    this.labourName,
    this.uomName,
    this.sequence = 10,
    this.quantity = 1.0,
    this.rate = 0.0,
  });

  final int? id;
  final int? acId;
  final int labourId;
  final String? labourName;
  final String? uomName;
  final int sequence;
  final double quantity;
  final double rate;

  double get lineCost => quantity * rate;

  AcLabourLine copyWith({
    int? id,
    int? acId,
    int? labourId,
    String? labourName,
    String? uomName,
    int? sequence,
    double? quantity,
    double? rate,
  }) {
    return AcLabourLine(
      id: id ?? this.id,
      acId: acId ?? this.acId,
      labourId: labourId ?? this.labourId,
      labourName: labourName ?? this.labourName,
      uomName: uomName ?? this.uomName,
      sequence: sequence ?? this.sequence,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'ac_id': acId,
      'labour_id': labourId,
      'sequence': sequence,
      'quantity': quantity,
      'rate': rate,
    };
  }

  factory AcLabourLine.fromMap(Map<String, Object?> map) {
    return AcLabourLine(
      id: map['id'] as int?,
      acId: map['ac_id'] as int?,
      labourId: map['labour_id'] as int,
      labourName: map['labour_name'] as String?,
      uomName: map['uom_name'] as String?,
      sequence: map['sequence'] as int? ?? 10,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      rate: (map['rate'] as num?)?.toDouble() ?? 0,
    );
  }
}
