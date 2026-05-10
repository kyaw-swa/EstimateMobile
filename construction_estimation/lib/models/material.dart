/// Mirror of Odoo `construction.material` model.
///
/// Fields (Odoo):
/// - name          Char, required, indexed, UNIQUE
/// - uom_id        Many2one('construction.uom'),
///                 domain=[('uom_type', 'in', ['material', 'both'])]
/// - default_rate  Float(16, 4)
/// - active        Boolean, default True
///
/// NOTE: class name collides with Flutter's `Material` widget.
/// Importers should use `import 'package:flutter/material.dart' hide Material;`
/// or alias this import (`as m`) when both are needed.
library;

class Material {
  Material({
    this.id,
    required this.name,
    this.uomId,
    this.uomName,
    this.defaultRate = 0,
    this.active = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final int? id;
  final String name;

  /// FK to `construction_uom.id`. Nullable — mirrors Odoo Many2one (not required).
  final int? uomId;

  /// Display label for the linked UoM. Populated when read via JOIN; not stored.
  final String? uomName;

  final double defaultRate;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  Material copyWith({
    int? id,
    String? name,
    int? uomId,
    bool clearUomId = false,
    String? uomName,
    double? defaultRate,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Material(
      id: id ?? this.id,
      name: name ?? this.name,
      uomId: clearUomId ? null : (uomId ?? this.uomId),
      uomName: clearUomId ? null : (uomName ?? this.uomName),
      defaultRate: defaultRate ?? this.defaultRate,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Persistable fields only — `uomName` is derived via JOIN, not stored.
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'uom_id': uomId,
      'default_rate': defaultRate,
      'active': active ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// [map] may include `uom_name` when produced by a JOIN query.
  factory Material.fromMap(Map<String, Object?> map) {
    return Material(
      id: map['id'] as int?,
      name: map['name'] as String,
      uomId: map['uom_id'] as int?,
      uomName: map['uom_name'] as String?,
      defaultRate: (map['default_rate'] as num?)?.toDouble() ?? 0,
      active: (map['active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() =>
      'Material(id: $id, name: $name, uomId: $uomId, defaultRate: $defaultRate)';
}
