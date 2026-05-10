# Construction Estimation - Mobile App

## Project Overview
ဒါက Odoo `construction_estimation` module ကို standalone Android app
အဖြစ် ပြန်ရေးတဲ့ project ပါ။ Flutter + sqflite (local database) သုံးတယ်။
**Odoo နဲ့ ဘာမှ မချိတ်ပါ။** Odoo source code က specification အနေနဲ့ပဲ သုံးတယ်။

## Reference Source
Odoo module path: `./odoo_reference/construction_estimation/`
လိုအပ်တဲ့ field name၊ business logic၊ workflow တွေကို ဒီကနေ ယူပါ။

## Tech Stack
- Flutter 3.x, Dart 3.x
- Material 3 design
- State management: provider
- Database: sqflite (local SQLite)
- PDF generation: pdf + printing packages (BOQ report အတွက်)
- Export: csv, share_plus
- Date handling: intl

## Architecture Rules
1. Layer separation: models → database → repositories → services → screens
2. Business logic ကို services/ မှာပဲထား၊ screens မှာ မရေး
3. Database access ကို repositories ကနေပဲ — UI က တိုက်ရိုက်မဝင်ရ
4. Odoo field name တွေကို တိတိကျကျ လိုက်နာ (snake_case → Dart camelCase ပြောင်း ok)
5. Selection field → Dart enum
6. Many2one → int? + Many2oneRef helper class
7. One2many → List<ChildModel>, parent save လုပ်တဲ့အခါ cascade

## Naming Conventions
- Model class: PascalCase (Material, ProjectEstimate)
- File: snake_case (material.dart, project_estimate.dart)
- Table: snake_case (materials, project_estimates)
- Foreign key column: `<parent>_id` (material_id, estimate_id)

## Key Models (from Odoo)
1. construction.uom              → UnitOfMeasure (master)
2. construction.material         → Material (master)
3. construction.labour           → Labour (master)
4. construction.ac               → AbstractOfCost (template)
5. construction.ac.material      → ACMaterial (line)
6. construction.ac.labour        → ACLabour (line)
7. construction.project.estimate → ProjectEstimate (transaction)
8. construction.estimate.line    → EstimateLine (line)
9. construction.estimate.line.material → EstimateLineMaterial
10. construction.estimate.line.labour  → EstimateLineLabour

## Progress Tracking
PLAN.md ကို ကြည့်ပါ။ Model တစ်ခုပြီးတိုင်း PLAN.md ကို update လုပ်ပါ။

## Workflow
- Session တစ်ခုမှာ model တစ်ခုထက် မပိုလုပ်နဲ့
- File generate လုပ်ပြီးတိုင်း `flutter analyze` run
- Many2one picker, selection dropdown လို reusable widget တွေကို
  widgets/ folder မှာ တစ်ခါပဲ ရေးပြီး ပြန်သုံး
