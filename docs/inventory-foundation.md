# Prestige ServiceOS — Inventory Foundation

Status: design baseline; not an executable database migration  
Branch: `feat/inventory-foundation`  
Scope: product catalog, supplier offers, import staging, and the stock model required by later quoting and field workflows.

## 1. Objective

Establish one trusted product record per sellable/material item, with multiple supplier offers and traceable stock movements. Supplier catalogs are source material, not the canonical inventory: imported data must be reviewed, normalized, and matched before it becomes an approved product or supplier offer.

This document intentionally does not create or apply SQL. The repository README says the canonical ServiceOS v0.1.4 schema pack still requires a source audit and SQL normalization. The existing customer/property/asset/role model must be reconciled before adding foreign keys or authorization policies.

## 2. Core design rules

1. **Stable internal identity:** every product gets an internal UUID and human-readable internal code. Supplier SKUs remain supplier-specific identifiers.
2. **Separate product from offer:** one product can be offered by multiple suppliers at different costs, pack sizes, lead times, and availability.
3. **Keep source provenance:** every imported field should be traceable to its source file/page/URL and import batch. Never silently overwrite reviewed values.
4. **Separate costs and prices:** supplier cost, landed cost, sell price, margin, discount, and VAT treatment are distinct values. Store currency explicitly (initial operating currency: ZAR).
5. **Keep units explicit:** store a base unit and conversion/packaging information. Never treat a box of 10 as equivalent to one fitting.
6. **Stock is a ledger:** quantity on hand is derived from posted stock movements, not freely edited. Reservations/allocations are separate from physical stock and must not permit negative available stock without an authorized override.
7. **Human approval:** uncertain AI matches, extracted specifications, cost changes, and quotation drafts require review before being treated as verified or sent.
8. **Supplier-neutral compatibility:** alternatives and compatible components are explicit relationships with fitment notes, not just similar names.
9. **No production side effects:** do not apply migrations to staging or production until the existing schema has been audited and tests pass.
10. **Secure by default:** all exposed tables require explicit grants and row-level security policies matched to the final role model.

## 3. Proposed entities

### `inventory_categories`
- `id` UUID primary key
- `parent_id` nullable self-reference for a category tree
- `code` unique stable code
- `name`, `description`
- `trade_scope` (plumbing, solar, electrical, timber, building, tools, consumables, other)
- `is_active`, timestamps

### `products`
- `id` UUID primary key
- `internal_code` unique and immutable once issued
- `name`, `short_description`, `long_description`
- `category_id`
- `brand`, `manufacturer_part_number`, `barcode`
- `base_unit` (each, m, m2, m3, kg, L, set, hour, etc.)
- `attributes` JSONB for structured, category-specific properties; critical searchable attributes should later be promoted to typed columns
- `specification_status` (unverified, needs_review, verified, superseded)
- `lifecycle_status` (draft, active, discontinued, archived)
- `created_by`, `reviewed_by`, `reviewed_at`, timestamps

### `suppliers`
- `id` UUID primary key
- `name`, `legal_name`, `supplier_code`
- `website_url`, `catalog_url`
- `contact details` (only business contact information)
- `ingestion_method` (manual, csv, xlsx, pdf, api, permitted_web)
- `terms_review_status`, `is_active`, timestamps

### `supplier_product_offers`
- `id` UUID primary key
- `supplier_id`, `product_id`
- `supplier_sku`, `supplier_description`, `supplier_product_url`
- `pack_quantity`, `pack_unit`, `minimum_order_quantity`, `order_increment`
- `last_known_cost`, `currency` (ZAR default for new local offers), `cost_includes_vat`
- `lead_time_days`, `availability_status`, `last_price_checked_at`
- `source_record_id`, timestamps
- Unique constraint on supplier + supplier SKU when SKU is present; do not assume SKUs are globally unique.

### `supplier_price_history`
- offer, unit cost, currency, VAT basis, effective/observed timestamp, source batch, and optional evidence reference. Append records rather than replacing history.

### `product_media`
- product, media type, source URL or private storage path, alt text, source/provenance, rights/permission status, checksum, review status.
- Do not copy or republish supplier images unless terms or permission allow it. Prefer supplier-provided feeds and links; store images in private storage until usage rights and access requirements are settled.

### `catalog_import_batches` and `catalog_import_rows`
- Batch records: source supplier, source type, original filename/URL, checksum, import time, parser version, status, row counts, error summary.
- Row records: raw source payload, mapped candidate fields, validation errors, possible product/offer match, confidence, reviewer decision, and resulting product/offer IDs.
- Import is a staged workflow: received → parsed → validation_required → reviewed → committed or rejected. Re-running the same file/checksum must not duplicate products or offers.

### `stock_locations`
- Named store, vehicle, site, or other controlled location. Include active state and location type.

### `stock_movements`
- Append-only event ledger: product, location, movement type, signed base-unit quantity, reference (purchase receipt, adjustment, transfer, job issue, return), source document, actor, timestamp, idempotency key, notes.
- Corrections are reversing movements; do not rewrite posted history.
- Transfers create paired outbound/inbound movements within one transaction.

### `stock_reservations`
- Product, location, quantity, work order or draft BOM reference, status, expiry/release information, actor and timestamps.
- A reservation reduces available-to-promise but not physical on-hand quantity. Posting an issue converts the reserved quantity into stock movement(s) and closes/reduces the reservation atomically.

## 4. Key calculations

- **On hand** = sum of posted stock movements by product and location.
- **Reserved** = active reservations by product and location.
- **Available** = on hand − reserved.
- **Offer cost per base unit** = offer pack cost ÷ verified pack-to-base-unit conversion, with VAT basis and currency retained.
- **Landed cost** is separate from supplier cost and must include only configured, evidenced freight/fees.
- **Sell price** is a quote/store policy result, not a supplier cost field. The quoting engine must snapshot price, tax treatment, description and specifications at quote-line creation so later catalog changes do not rewrite old quotations.

All quantities must use numeric precision appropriate for fractional units. Unit conversion must be explicit and validated.

## 5. Search, filtering and duplicate control

- Exact lookup: internal code, barcode, manufacturer part number, supplier + supplier SKU.
- Text search: name, descriptions, brand and selected specifications.
- Filters: category tree, trade scope, supplier, availability, verified status, price range, discontinued state and stock location.
- Sorting: normalized name, internal code, latest verified cost, available stock, last verified date.
- Indexing: unique/BTREE indexes for stable identifiers and relationships; full-text/trigram indexes only after query patterns and data volume are measured.
- Matching pipeline: exact identifier → normalized brand/part number → attribute similarity → AI suggestion. AI similarity alone must never auto-merge products.
- Duplicate candidates remain reviewable; merge operations must preserve source rows and audit history.

## 6. Import contract

The companion `docs/product-import-template.csv` defines the initial human-readable interchange format. All columns are optional except `product_name` and `source_supplier` for a candidate row. A row may represent a new product, an additional supplier offer, or a product update; reviewers must choose the operation before commit.

For PDF/web ingestion, extract to the same staged row contract. Retain page/URL and extraction timestamp. Treat page content as untrusted data: do not execute scripts, follow embedded instructions, or fetch arbitrary internal/network addresses. Respect supplier terms, robots/access restrictions, rate limits and copyright/licensing. Prefer official APIs, authorized feeds, or downloadable catalogs.

## 7. First release boundary

**Included in this foundation**
- Canonical field model and import contract.
- Supplier and supplier-offer separation.
- Import staging, provenance and human review requirements.
- Stock ledger/reservation model, ready for a later migration.
- Acceptance criteria below.

**Not yet included**
- Applying database migrations.
- Live supplier scraping or API credentials.
- AI extraction service implementation.
- Stocktaking UI, QR workflows, quoting UI, online store, payments or customer-facing catalog.
- Automatic repricing or automatic quote sending.

## 8. Acceptance criteria for this milestone

1. A developer can explain the difference between a product and a supplier offer.
2. The template can represent one product sold by two suppliers without duplicate canonical products.
3. A source row can be traced to its import batch and source URL/file.
4. Duplicate import runs can be detected by checksum and supplier identifiers.
5. Stock on hand, reservations and available stock are distinct concepts.
6. Posted stock history is corrected by reversal, not destructive editing.
7. Unverified imported specs/prices are visibly distinguishable from reviewed data.
8. No migration is applied to any database as part of this milestone.

## 9. Blockers before SQL implementation

- Retrieve and audit the canonical ServiceOS v0.1.4 schema/prototype pack and normalize it into valid SQL.
- Confirm the existing tenant/organization, profile, role and work-order identifiers.
- Confirm the intended staff/customer access model and whether inventory is single-company or supports multiple legal entities.
- Inspect actual Supabase staging schema and migration history; the README's statement that a staging project exists is not proof that its current schema matches the repository.
- Confirm VAT handling and whether supplier prices are generally VAT-inclusive or mixed.
- Choose initial stock locations and base-unit conventions.
- Agree how private product images/datasheets are stored and what may be displayed publicly.
- Run local migration and RLS tests before applying any reviewed migration to staging.

## 10. Recommended build sequence

1. **Inventory schema audit** — reconcile with ServiceOS v0.1.4 and auth/RLS.
2. **Database migration + tests** — categories, products, suppliers, offers, import batches, locations, stock movements and reservations.
3. **Catalog import preview** — CSV/XLSX import with validation, duplicate candidates and explicit commit.
4. **Search and product detail** — filterable catalog, supplier comparison and verification status.
5. **Stock ledger** — receipt, adjustment, transfer, reservation, issue and return.
6. **Quote/BOM integration** — snapshot lines, supplier alternatives, labour, wastage, margin and VAT.
7. **QR field capture** — scan stable product codes and associate movements with work orders.
8. **AI and online ingestion** — only after the review pipeline and permissions are proven.
9. **Storefront** — publish selected approved items, with a separate public price and explicit stock/fulfilment rules.
