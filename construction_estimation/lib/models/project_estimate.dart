/// Mirror of Odoo `construction.project.estimate` and its 3-level child
/// hierarchy.
///
/// **Tree:** ProjectEstimate → EstimateLine → EstimateLineMaterial / Labour
///
/// **Customer:** Odoo uses `customer_id Many2one(res.partner)`. This single-
/// user app has no partner registry — we store a free-text `customerName`.
///
/// **Computed fields:** Odoo stores totals/area/volume/base_qty/suggested_qty/
/// amount as `compute=, store=True`. We compute them in Dart on the fly to
/// avoid persistence complexity. Only inputs are stored.
///
/// **Detailed Measurement (Section/Subelement/Measurement) is NOT included in
/// this phase** — Odoo's `construction.estimate.line.section`/`.subelement`/
/// `.measurement` tables are deferred to a later phase.
library;

import 'abstract_of_cost.dart' show MeasurementType;

export 'abstract_of_cost.dart' show MeasurementType;

/// Odoo `state` selection for estimates.
enum EstimateState {
  draft('draft', 'Draft'),
  confirmed('confirmed', 'Confirmed'),
  cancelled('cancelled', 'Cancelled');

  const EstimateState(this.value, this.label);

  final String value;
  final String label;

  static EstimateState fromValue(String? raw) {
    return EstimateState.values.firstWhere(
      (s) => s.value == raw,
      orElse: () => EstimateState.draft,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Parent: construction.project.estimate
// ─────────────────────────────────────────────────────────────────────────────

class ProjectEstimate {
  ProjectEstimate({
    this.id,
    required this.name,
    this.customerName,
    this.date,
    this.state = EstimateState.draft,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<EstimateLine>? lines,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        lines = lines ?? const [];

  final int? id;
  final String name;
  final String? customerName;
  final DateTime? date;
  final EstimateState state;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  final List<EstimateLine> lines;

  /// Sum of every line's material total.
  double get totalMaterialCost =>
      lines.fold(0, (s, l) => s + l.materialTotal);

  /// Sum of every line's labour total.
  double get totalLabourCost => lines.fold(0, (s, l) => s + l.labourTotal);

  /// Material + labour across all lines.
  double get grandTotal => totalMaterialCost + totalLabourCost;

  ProjectEstimate copyWith({
    int? id,
    String? name,
    String? customerName,
    bool clearCustomerName = false,
    DateTime? date,
    bool clearDate = false,
    EstimateState? state,
    String? notes,
    bool clearNotes = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<EstimateLine>? lines,
  }) {
    return ProjectEstimate(
      id: id ?? this.id,
      name: name ?? this.name,
      customerName:
          clearCustomerName ? null : (customerName ?? this.customerName),
      date: clearDate ? null : (date ?? this.date),
      state: state ?? this.state,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lines: lines ?? this.lines,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'customer_name': customerName,
      'date': date?.toIso8601String(),
      'state': state.value,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ProjectEstimate.fromMap(
    Map<String, Object?> map, {
    List<EstimateLine> lines = const [],
  }) {
    final dateRaw = map['date'] as String?;
    return ProjectEstimate(
      id: map['id'] as int?,
      name: map['name'] as String,
      customerName: map['customer_name'] as String?,
      date: dateRaw != null ? DateTime.parse(dateRaw) : null,
      state: EstimateState.fromValue(map['state'] as String?),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lines: lines,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  construction.estimate.line
// ─────────────────────────────────────────────────────────────────────────────

class EstimateLine {
  EstimateLine({
    this.id,
    this.estimateId,
    required this.acId,
    this.acName,
    this.baseUomName,
    this.sequence = 10,
    this.reference,
    this.measurementType = MeasurementType.sqft,
    this.uomId,
    this.uomName,
    this.lengthFt = 0,
    this.lengthIn = 0,
    this.breadthFt = 0,
    this.breadthIn = 0,
    this.heightFt = 0,
    this.heightIn = 0,
    List<EstimateLineMaterial>? materialDetails,
    List<EstimateLineLabour>? labourDetails,
  })  : materialDetails = materialDetails ?? const [],
        labourDetails = labourDetails ?? const [];

  final int? id;
  final int? estimateId;

  /// Required FK — every estimate line is tied to a work item (AC).
  final int acId;

  /// Joined display label for the AC.
  final String? acName;

  /// Joined display label for the AC's `base_uom_id` (e.g. "Sqft").
  final String? baseUomName;

  final int sequence;
  final String? reference;
  final MeasurementType measurementType;
  final int? uomId;
  final String? uomName;

  // Dimension inputs — feet and inches, stored separately like Odoo.
  final double lengthFt;
  final double lengthIn;
  final double breadthFt;
  final double breadthIn;
  final double heightFt;
  final double heightIn;

  final List<EstimateLineMaterial> materialDetails;
  final List<EstimateLineLabour> labourDetails;

  /// Decimal feet from feet + inches.
  static double _decimalFeet(double ft, double inch) => ft + inch / 12.0;

  double get _length => _decimalFeet(lengthFt, lengthIn);
  double get _breadth => _decimalFeet(breadthFt, breadthIn);
  double get _height => _decimalFeet(heightFt, heightIn);

  /// L × B (Sqft). Zero for cuft lines.
  double get area =>
      measurementType == MeasurementType.sqft ? _length * _breadth : 0;

  /// L × B × H (Cuft). Zero for sqft lines.
  double get volume =>
      measurementType == MeasurementType.cuft
          ? _length * _breadth * _height
          : 0;

  /// Effective base quantity used to scale material/labour suggested qtys.
  /// Always derived from dimensions — area for sqft, volume for cuft.
  double get baseQty =>
      measurementType == MeasurementType.cuft ? volume : area;

  double get materialTotal =>
      materialDetails.fold(0, (s, d) => s + d.amount);
  double get labourTotal => labourDetails.fold(0, (s, d) => s + d.amount);
  double get totalCost => materialTotal + labourTotal;

  EstimateLine copyWith({
    int? id,
    int? estimateId,
    int? acId,
    String? acName,
    String? baseUomName,
    int? sequence,
    String? reference,
    bool clearReference = false,
    MeasurementType? measurementType,
    int? uomId,
    bool clearUomId = false,
    String? uomName,
    double? lengthFt,
    double? lengthIn,
    double? breadthFt,
    double? breadthIn,
    double? heightFt,
    double? heightIn,
    List<EstimateLineMaterial>? materialDetails,
    List<EstimateLineLabour>? labourDetails,
  }) {
    return EstimateLine(
      id: id ?? this.id,
      estimateId: estimateId ?? this.estimateId,
      acId: acId ?? this.acId,
      acName: acName ?? this.acName,
      baseUomName: baseUomName ?? this.baseUomName,
      sequence: sequence ?? this.sequence,
      reference: clearReference ? null : (reference ?? this.reference),
      measurementType: measurementType ?? this.measurementType,
      uomId: clearUomId ? null : (uomId ?? this.uomId),
      uomName: clearUomId ? null : (uomName ?? this.uomName),
      lengthFt: lengthFt ?? this.lengthFt,
      lengthIn: lengthIn ?? this.lengthIn,
      breadthFt: breadthFt ?? this.breadthFt,
      breadthIn: breadthIn ?? this.breadthIn,
      heightFt: heightFt ?? this.heightFt,
      heightIn: heightIn ?? this.heightIn,
      materialDetails: materialDetails ?? this.materialDetails,
      labourDetails: labourDetails ?? this.labourDetails,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'estimate_id': estimateId,
      'ac_id': acId,
      'sequence': sequence,
      'reference': reference,
      'measurement_type': measurementType.value,
      'uom_id': uomId,
      'length_ft': lengthFt,
      'length_in': lengthIn,
      'breadth_ft': breadthFt,
      'breadth_in': breadthIn,
      'height_ft': heightFt,
      'height_in': heightIn,
    };
  }

  factory EstimateLine.fromMap(
    Map<String, Object?> map, {
    List<EstimateLineMaterial> materialDetails = const [],
    List<EstimateLineLabour> labourDetails = const [],
  }) {
    return EstimateLine(
      id: map['id'] as int?,
      estimateId: map['estimate_id'] as int?,
      acId: map['ac_id'] as int,
      acName: map['ac_name'] as String?,
      baseUomName: map['base_uom_name'] as String?,
      sequence: map['sequence'] as int? ?? 10,
      reference: map['reference'] as String?,
      measurementType:
          MeasurementType.fromValue(map['measurement_type'] as String?),
      uomId: map['uom_id'] as int?,
      uomName: map['uom_name'] as String?,
      lengthFt: (map['length_ft'] as num?)?.toDouble() ?? 0,
      lengthIn: (map['length_in'] as num?)?.toDouble() ?? 0,
      breadthFt: (map['breadth_ft'] as num?)?.toDouble() ?? 0,
      breadthIn: (map['breadth_in'] as num?)?.toDouble() ?? 0,
      heightFt: (map['height_ft'] as num?)?.toDouble() ?? 0,
      heightIn: (map['height_in'] as num?)?.toDouble() ?? 0,
      materialDetails: materialDetails,
      labourDetails: labourDetails,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  construction.estimate.line.material  /  .labour
//
//  Both follow the same shape — single mixin-style base class would tangle
//  generics so we duplicate. The `_LineDetail` doc below applies to both.
// ─────────────────────────────────────────────────────────────────────────────

/// Shared formula:
///   suggested_qty = (parent.baseQty / template_base_qty) × template_qty
///   amount        = (quantity × rate) / per
///
/// `quantity` always tracks `suggestedQty` — there is no manual override.
/// Repository syncs the stored quantity to suggestedQty on save.
class EstimateLineMaterial {
  EstimateLineMaterial({
    this.id,
    this.lineId,
    required this.materialId,
    this.materialName,
    this.uomName,
    this.sequence = 10,
    this.reference,
    this.templateQty = 0,
    this.templateBaseQty = 1,
    this.quantity = 0,
    this.rate = 0,
    this.per = 1,
    this.parentBaseQty = 0,
  });

  final int? id;
  final int? lineId;

  final int materialId;
  final String? materialName;
  final String? uomName;

  final int sequence;
  final String? reference;

  final double templateQty;
  final double templateBaseQty;

  /// Stored quantity. Tracks `suggestedQty`; repository syncs on save.
  final double quantity;

  final double rate;
  final double per;

  /// Transient — set by the repository on read so `suggestedQty` can be
  /// computed without needing the parent line in scope.
  final double parentBaseQty;

  /// `(parent.baseQty / template_base_qty) × template_qty`.
  double get suggestedQty {
    final base = templateBaseQty == 0 ? 1.0 : templateBaseQty;
    return (parentBaseQty / base) * templateQty;
  }

  /// `(suggestedQty × rate) / per`. Falls back to per=1 when zero.
  /// Uses suggestedQty (live from dimensions) rather than the stored
  /// `quantity` so totals stay correct before the repository syncs on save.
  double get amount {
    final divisor = per == 0 ? 1.0 : per;
    return (suggestedQty * rate) / divisor;
  }

  EstimateLineMaterial copyWith({
    int? id,
    int? lineId,
    int? materialId,
    String? materialName,
    String? uomName,
    int? sequence,
    String? reference,
    bool clearReference = false,
    double? templateQty,
    double? templateBaseQty,
    double? quantity,
    double? rate,
    double? per,
    double? parentBaseQty,
  }) {
    return EstimateLineMaterial(
      id: id ?? this.id,
      lineId: lineId ?? this.lineId,
      materialId: materialId ?? this.materialId,
      materialName: materialName ?? this.materialName,
      uomName: uomName ?? this.uomName,
      sequence: sequence ?? this.sequence,
      reference: clearReference ? null : (reference ?? this.reference),
      templateQty: templateQty ?? this.templateQty,
      templateBaseQty: templateBaseQty ?? this.templateBaseQty,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      per: per ?? this.per,
      parentBaseQty: parentBaseQty ?? this.parentBaseQty,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'line_id': lineId,
      'material_id': materialId,
      'sequence': sequence,
      'reference': reference,
      'template_qty': templateQty,
      'template_base_qty': templateBaseQty,
      'quantity': quantity,
      'rate': rate,
      'per': per,
    };
  }

  factory EstimateLineMaterial.fromMap(
    Map<String, Object?> map, {
    double parentBaseQty = 0,
  }) {
    return EstimateLineMaterial(
      id: map['id'] as int?,
      lineId: map['line_id'] as int?,
      materialId: map['material_id'] as int,
      materialName: map['material_name'] as String?,
      uomName: map['uom_name'] as String?,
      sequence: map['sequence'] as int? ?? 10,
      reference: map['reference'] as String?,
      templateQty: (map['template_qty'] as num?)?.toDouble() ?? 0,
      templateBaseQty: (map['template_base_qty'] as num?)?.toDouble() ?? 1,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      rate: (map['rate'] as num?)?.toDouble() ?? 0,
      per: (map['per'] as num?)?.toDouble() ?? 1,
      parentBaseQty: parentBaseQty,
    );
  }
}

class EstimateLineLabour {
  EstimateLineLabour({
    this.id,
    this.lineId,
    required this.labourId,
    this.labourName,
    this.uomName,
    this.sequence = 10,
    this.reference,
    this.templateQty = 0,
    this.templateBaseQty = 1,
    this.quantity = 0,
    this.rate = 0,
    this.per = 1,
    this.parentBaseQty = 0,
  });

  final int? id;
  final int? lineId;

  final int labourId;
  final String? labourName;
  final String? uomName;

  final int sequence;
  final String? reference;

  final double templateQty;
  final double templateBaseQty;

  final double quantity;
  final double rate;
  final double per;

  final double parentBaseQty;

  double get suggestedQty {
    final base = templateBaseQty == 0 ? 1.0 : templateBaseQty;
    return (parentBaseQty / base) * templateQty;
  }

  double get amount {
    final divisor = per == 0 ? 1.0 : per;
    return (quantity * rate) / divisor;
  }

  EstimateLineLabour copyWith({
    int? id,
    int? lineId,
    int? labourId,
    String? labourName,
    String? uomName,
    int? sequence,
    String? reference,
    bool clearReference = false,
    double? templateQty,
    double? templateBaseQty,
    double? quantity,
    double? rate,
    double? per,
    double? parentBaseQty,
  }) {
    return EstimateLineLabour(
      id: id ?? this.id,
      lineId: lineId ?? this.lineId,
      labourId: labourId ?? this.labourId,
      labourName: labourName ?? this.labourName,
      uomName: uomName ?? this.uomName,
      sequence: sequence ?? this.sequence,
      reference: clearReference ? null : (reference ?? this.reference),
      templateQty: templateQty ?? this.templateQty,
      templateBaseQty: templateBaseQty ?? this.templateBaseQty,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      per: per ?? this.per,
      parentBaseQty: parentBaseQty ?? this.parentBaseQty,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'line_id': lineId,
      'labour_id': labourId,
      'sequence': sequence,
      'reference': reference,
      'template_qty': templateQty,
      'template_base_qty': templateBaseQty,
      'quantity': quantity,
      'rate': rate,
      'per': per,
    };
  }

  factory EstimateLineLabour.fromMap(
    Map<String, Object?> map, {
    double parentBaseQty = 0,
  }) {
    return EstimateLineLabour(
      id: map['id'] as int?,
      lineId: map['line_id'] as int?,
      labourId: map['labour_id'] as int,
      labourName: map['labour_name'] as String?,
      uomName: map['uom_name'] as String?,
      sequence: map['sequence'] as int? ?? 10,
      reference: map['reference'] as String?,
      templateQty: (map['template_qty'] as num?)?.toDouble() ?? 0,
      templateBaseQty: (map['template_base_qty'] as num?)?.toDouble() ?? 1,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      rate: (map['rate'] as num?)?.toDouble() ?? 0,
      per: (map['per'] as num?)?.toDouble() ?? 1,
      parentBaseQty: parentBaseQty,
    );
  }
}
