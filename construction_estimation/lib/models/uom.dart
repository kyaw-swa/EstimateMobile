/// Mirror of Odoo `construction.uom` model.
///
/// Fields (Odoo):
/// - name      Char, required
/// - uom_type  Selection [material/labour/both], default 'both', required
/// - active    Boolean, default True
library;

/// Odoo `uom_type` selection — which contexts a UoM may be used in.
enum UomType {
  material('material', 'Material'),
  labour('labour', 'Labour'),
  both('both', 'Both');

  const UomType(this.value, this.label);

  /// Odoo selection key (stored in DB).
  final String value;

  /// Human-readable label.
  final String label;

  static UomType fromValue(String? raw) {
    return UomType.values.firstWhere(
      (t) => t.value == raw,
      orElse: () => UomType.both,
    );
  }
}

class UnitOfMeasure {
  UnitOfMeasure({
    this.id,
    required this.name,
    this.uomType = UomType.both,
    this.active = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final int? id;
  final String name;
  final UomType uomType;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// True if this UoM may be used for materials.
  bool get usableForMaterial =>
      uomType == UomType.material || uomType == UomType.both;

  /// True if this UoM may be used for labour.
  bool get usableForLabour =>
      uomType == UomType.labour || uomType == UomType.both;

  UnitOfMeasure copyWith({
    int? id,
    String? name,
    UomType? uomType,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UnitOfMeasure(
      id: id ?? this.id,
      name: name ?? this.name,
      uomType: uomType ?? this.uomType,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'uom_type': uomType.value,
      'active': active ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UnitOfMeasure.fromMap(Map<String, Object?> map) {
    return UnitOfMeasure(
      id: map['id'] as int?,
      name: map['name'] as String,
      uomType: UomType.fromValue(map['uom_type'] as String?),
      active: (map['active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() =>
      'UnitOfMeasure(id: $id, name: $name, uomType: ${uomType.value})';
}
