import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/project_estimate.dart';

/// Renders a Bill of Quantities PDF for a [ProjectEstimate].
///
/// Layout follows `odoo_reference/.../report/project_estimate_report.xml`:
/// each estimate line becomes a numbered header row, with nested Material /
/// Labour sub-tables underneath and a per-line subtotal. The document closes
/// with grand-total rows. Detailed measurement sections (deferred from
/// Phase 4) are omitted.
class BoqPdfService {
  BoqPdfService();

  static final _dateFmt = DateFormat('d MMM yyyy');
  static final _qty3 = NumberFormat('#,##0.000');
  static final _qty2 = NumberFormat('#,##0.00');
  static final _money = NumberFormat('#,##0.00');

  /// Build a PDF document (Uint8List) ready for preview / share / save.
  Future<Uint8List> build(ProjectEstimate estimate) async {
    final doc = pw.Document(
      title: 'BOQ - ${estimate.name}',
      author: 'Construction Estimation',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 36, 28, 36),
        header: (ctx) => _runningHeader(ctx, estimate),
        footer: _pageFooter,
        build: (ctx) => [
          _buildTitle(estimate),
          pw.SizedBox(height: 12),
          _buildMeta(estimate),
          pw.SizedBox(height: 16),
          _buildBoqTable(estimate),
          pw.SizedBox(height: 12),
          _buildGrandTotals(estimate),
          if (estimate.notes != null && estimate.notes!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildNotes(estimate.notes!.trim()),
          ],
        ],
      ),
    );

    return doc.save();
  }

  /// Show the OS print / share / save dialog backed by the `printing` plugin.
  Future<void> preview(ProjectEstimate estimate) async {
    await Printing.layoutPdf(
      name: _safeFileName(estimate),
      onLayout: (_) => build(estimate),
    );
  }

  /// Share the PDF via the system share sheet (WhatsApp, Email, etc.).
  Future<void> share(ProjectEstimate estimate) async {
    final bytes = await build(estimate);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${_safeFileName(estimate)}.pdf',
    );
  }

  String _safeFileName(ProjectEstimate e) {
    final raw = 'BOQ_${e.name}';
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }

  // ─────────────────────────── Header / Footer ───────────────────────────

  pw.Widget _runningHeader(pw.Context ctx, ProjectEstimate estimate) {
    if (ctx.pageNumber == 1) return pw.SizedBox();
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        'BOQ — ${estimate.name}',
        style: pw.TextStyle(
          fontSize: 9,
          color: PdfColors.grey700,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  pw.Widget _pageFooter(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  // ─────────────────────────── Title / Meta ──────────────────────────────

  pw.Widget _buildTitle(ProjectEstimate e) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Bill of Quantities',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          e.name,
          style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey800),
        ),
      ],
    );
  }

  pw.Widget _buildMeta(ProjectEstimate e) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 2,
          child: _metaItem('Customer', e.customerName ?? '—'),
        ),
        pw.Expanded(
          child: _metaItem(
            'Date',
            e.date != null ? _dateFmt.format(e.date!) : '—',
          ),
        ),
        pw.Expanded(child: _metaItem('State', e.state.label)),
      ],
    );
  }

  pw.Widget _metaItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey600,
            letterSpacing: 0.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  // ─────────────────────────── BOQ Table ─────────────────────────────────

  static const _borderColor = PdfColors.grey400;
  static const _headerFill = PdfColors.grey200;
  static const _subHeaderFill = PdfColors.grey100;

  /// 7 columns: No 5%, Particular 38%, Qty 12%, Unit 8%, Rate 12%, Per 7%,
  /// Amount 18%.
  static const _colFlex = <double>[5, 38, 12, 8, 12, 7, 18];

  pw.Widget _buildBoqTable(ProjectEstimate e) {
    final rows = <pw.TableRow>[_headerRow()];

    if (e.lines.isEmpty) {
      rows.add(_emptyRow());
    }

    var idx = 0;
    for (final line in e.lines) {
      idx += 1;
      rows.add(_lineHeaderRow(idx, line));

      if (line.materialDetails.isNotEmpty) {
        rows.add(_sectionLabelRow('Materials'));
        for (final m in line.materialDetails) {
          rows.add(_detailRow(
            name: m.materialName ?? 'Material #${m.materialId}',
            reference: m.reference,
            quantity: m.quantity,
            uom: m.uomName,
            rate: m.rate,
            per: m.per,
            amount: m.amount,
          ));
        }
      }

      if (line.labourDetails.isNotEmpty) {
        rows.add(_sectionLabelRow('Labours'));
        for (final l in line.labourDetails) {
          rows.add(_detailRow(
            name: l.labourName ?? 'Labour #${l.labourId}',
            reference: l.reference,
            quantity: l.quantity,
            uom: l.uomName,
            rate: l.rate,
            per: l.per,
            amount: l.amount,
          ));
        }
      }

      rows.add(_subtotalRow(line.totalCost));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      columnWidths: {
        for (var i = 0; i < _colFlex.length; i++)
          i: pw.FlexColumnWidth(_colFlex[i]),
      },
      children: rows,
    );
  }

  pw.TableRow _headerRow() {
    pw.Widget head(String text, {pw.Alignment align = pw.Alignment.center}) {
      return pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        color: _headerFill,
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      );
    }

    return pw.TableRow(
      children: [
        head('No.'),
        head('Particular', align: pw.Alignment.centerLeft),
        head('Quantity', align: pw.Alignment.centerRight),
        head('Unit'),
        head('Rate', align: pw.Alignment.centerRight),
        head('Per', align: pw.Alignment.centerRight),
        head('Amount', align: pw.Alignment.centerRight),
      ],
    );
  }

  pw.TableRow _emptyRow() {
    return pw.TableRow(
      children: [
        for (var i = 0; i < _colFlex.length; i++)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 16),
            alignment: pw.Alignment.center,
            child: i == 1
                ? pw.Text(
                    'No work items',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  )
                : pw.SizedBox(),
          ),
      ],
    );
  }

  pw.TableRow _lineHeaderRow(int idx, EstimateLine line) {
    final particular = pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: line.acName ?? 'AC #${line.acId}',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (line.reference != null && line.reference!.isNotEmpty)
            pw.TextSpan(
              text: '  (${line.reference})',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
        ],
      ),
    );

    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _subHeaderFill),
      children: [
        _cell(idx.toString(), bold: true),
        _cellWidget(particular, align: pw.Alignment.centerLeft),
        _cell(_qty2.format(line.baseQty), align: pw.Alignment.centerRight),
        _cell(line.uomName ?? ''),
        _cell(''),
        _cell(''),
        _cell(''),
      ],
    );
  }

  pw.TableRow _sectionLabelRow(String label) {
    return pw.TableRow(
      children: [
        _cell(''),
        _cellWidget(
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
          align: pw.Alignment.centerLeft,
        ),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
      ],
    );
  }

  pw.TableRow _detailRow({
    required String name,
    String? reference,
    required double quantity,
    String? uom,
    required double rate,
    required double per,
    required double amount,
  }) {
    final particular = pw.Padding(
      padding: const pw.EdgeInsets.only(left: 8),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: name,
              style: const pw.TextStyle(fontSize: 9),
            ),
            if (reference != null && reference.isNotEmpty)
              pw.TextSpan(
                text: '  ($reference)',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
          ],
        ),
      ),
    );

    return pw.TableRow(
      children: [
        _cell(''),
        _cellWidget(particular, align: pw.Alignment.centerLeft),
        _cell(_qty3.format(quantity), align: pw.Alignment.centerRight),
        _cell(uom ?? ''),
        _cell(_money.format(rate), align: pw.Alignment.centerRight),
        _cell(_qty2.format(per), align: pw.Alignment.centerRight),
        _cell(_money.format(amount), align: pw.Alignment.centerRight),
      ],
    );
  }

  /// Per-line subtotal — label sits in the Per column, amount in Amount.
  pw.TableRow _subtotalRow(double subtotal) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _subHeaderFill),
      children: [
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell('Subtotal', align: pw.Alignment.centerRight, bold: true),
        _cell(
          _money.format(subtotal),
          align: pw.Alignment.centerRight,
          bold: true,
        ),
      ],
    );
  }

  // ─────────────────────────── Grand totals ──────────────────────────────

  /// Rendered as a small right-aligned table beneath the BOQ. Width matches
  /// roughly the right-hand portion of the main table.
  pw.Widget _buildGrandTotals(ProjectEstimate e) {
    pw.TableRow line(String label, double value, {bool emphasize = false}) {
      return pw.TableRow(
        decoration: pw.BoxDecoration(
          color: emphasize ? PdfColors.grey300 : _headerFill,
        ),
        children: [
          pw.Container(
            alignment: pw.Alignment.centerRight,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: emphasize ? 11 : 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(
              _money.format(value),
              style: pw.TextStyle(
                fontSize: emphasize ? 11 : 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    return pw.Row(
      children: [
        pw.Spacer(flex: 50),
        pw.Expanded(
          flex: 50,
          child: pw.Table(
            border: pw.TableBorder.all(color: _borderColor, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(60),
              1: pw.FlexColumnWidth(40),
            },
            children: [
              line('Total Material Cost', e.totalMaterialCost),
              line('Total Labour Cost', e.totalLabourCost),
              line('Grand Total', e.grandTotal, emphasize: true),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── Cell helpers ──────────────────────────────

  pw.Widget _cell(
    String text, {
    pw.Alignment align = pw.Alignment.center,
    bool bold = false,
    double fontSize = 9,
  }) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _cellWidget(
    pw.Widget child, {
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: child,
    );
  }

  // ─────────────────────────── Notes ─────────────────────────────────────

  pw.Widget _buildNotes(String notes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Notes',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(notes, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }
}
