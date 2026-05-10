# Construction Estimation App - Build Plan

## Build Order (depend ပေါ် မူတည်ပြီး စီထား)

### Phase 1: Foundation
- [x] Project setup (pubspec.yaml, folder structure)
- [x] Database helper (sqflite connection, migration, schema)
- [x] Common widgets (Many2onePicker, SelectionDropdown, NumericField, EmptyState, ConfirmDialog)
- [x] App theme + main navigation shell

### Phase 2: Master Data (depend မရှိ၊ အရင်လုပ်)
- [x] **UnitOfMeasure** (construction.uom)
  - [x] Model + table
  - [x] Repository
  - [x] List screen
  - [x] Form screen
  - [x] Seed default data (data/construction_uom_data.xml ထဲက)

- [x] **Material** (construction.material)
  - [x] Model + table (uom_id Many2one ပါ)
  - [x] Repository
  - [x] List screen + search
  - [x] Form screen

- [x] **Labour** (construction.labour)
  - [x] Model + table
  - [x] Repository
  - [x] List + form screens

### Phase 3: Templates (Master data depend)
- [x] **AbstractOfCost** (construction.ac)
  - [x] Parent model + table
  - [x] ACMaterial child model (One2many)
  - [x] ACLabour child model (One2many)
  - [x] Repository (cascade save/delete)
  - [x] List screen
  - [x] Form screen with material lines + labour lines tabs
  - [x] Total cost computation

### Phase 4: Transactions (Templates depend)
- [x] **ProjectEstimate** (construction.project.estimate)
  - [x] Parent model + table
  - [x] EstimateLine child (One2many)
  - [x] EstimateLineMaterial (nested One2many)
  - [x] EstimateLineLabour (nested One2many)
  - [x] Repository (3-level cascade)
  - [x] List screen
  - [x] Form screen (complex — multiple nested lines)
  - [x] State workflow (draft → confirmed → cancelled)
  - [x] Total computation across all levels
- Deferred to a later phase: Detailed Measurement (Section/Sub-element/
  Measurement) — Odoo's `construction.estimate.line.section` etc.

### Phase 5: Reports
- [ ] BOQ PDF generation (pdf package)
  - [ ] Layout matching Odoo QWeb report
  - [ ] Print / share / save to device

### Phase 6: Backup & Polish
- [ ] Backup screen (Settings)
  - [ ] Export full database file
  - [ ] Export to JSON
  - [ ] Export to CSV per model
  - [ ] Restore from backup file
- [ ] Backup reminder (7-day)
- [ ] App icon, splash screen
- [ ] Error handling, empty states
- [ ] flutter analyze clean

## Notes / Decisions
- Single user app — no authentication needed
- All data local — no sync, no online features
- PDF export instead of Odoo QWeb
- (add as you go...)

## Open Questions
- Project Estimate မှာ state workflow ရှိလား? (draft/confirmed/done?)
  → Odoo `project_estimate.py` ကို စစ်ရန်
- BOQ report format က Odoo နဲ့ အတိအကျတူရမလား?
- Material/Labour မှာ category / parent grouping ရှိလား?
