-- 0001_mvp_inventory.sql
-- MVP schema: suppliers, products, stock (with expiry lots), stock movements and alerts.
-- Draft for review. Run as pos_owner on database abarrotes_pos.
-- Money is integer centavos. Quantities use numeric(12,3) so weighed items (kg) fit.
-- IDs are client-generated UUIDs so offline devices can create rows without the server.

BEGIN;

CREATE TABLE store (
  id          uuid PRIMARY KEY,
  name        text NOT NULL,
  address     text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app_user (
  id          uuid PRIMARY KEY,
  store_id    uuid NOT NULL REFERENCES store(id),
  name        text NOT NULL,
  role        text NOT NULL CHECK (role IN ('owner', 'cashier')),
  pin_hash    text NOT NULL,                -- never store the PIN itself
  active      boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Product categories carry the default near-expiry warning (7 days, 3 for dairy and bread).
CREATE TABLE category (
  id                  uuid PRIMARY KEY,
  store_id            uuid NOT NULL REFERENCES store(id),
  name                text NOT NULL,
  expiry_warning_days smallint NOT NULL DEFAULT 7 CHECK (expiry_warning_days >= 0),
  UNIQUE (store_id, name)
);

CREATE TABLE supplier (
  id              uuid PRIMARY KEY,
  store_id        uuid NOT NULL REFERENCES store(id),
  name            text NOT NULL,
  contact_name    text,
  phone           text,
  whatsapp        text,
  visit_days      smallint[] NOT NULL DEFAULT '{}',   -- ISO weekday 1=Mon .. 7=Sun
  payment_terms_days smallint NOT NULL DEFAULT 0,      -- 0 = pays on delivery
  notes           text,
  active          boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (visit_days <@ ARRAY[1,2,3,4,5,6,7]::smallint[])
);

CREATE TABLE product (
  id                  uuid PRIMARY KEY,
  store_id            uuid NOT NULL REFERENCES store(id),
  category_id         uuid REFERENCES category(id),
  name                text NOT NULL,
  barcode             text,                         -- may be null (loose items)
  unit                text NOT NULL DEFAULT 'pza' CHECK (unit IN ('pza', 'kg', 'l')),
  price_centavos      integer NOT NULL CHECK (price_centavos >= 0),
  cost_centavos       integer CHECK (cost_centavos >= 0),
  min_stock           numeric(12,3) NOT NULL DEFAULT 0,  -- low-stock threshold
  reorder_qty         numeric(12,3),                     -- suggested order size
  tracks_expiry       boolean NOT NULL DEFAULT false,    -- only for chosen products
  expiry_warning_days smallint,                          -- overrides the category default
  -- tax data (rules come from the accountant role; CFDI fields kept for phase 3)
  iva_rate            text NOT NULL DEFAULT '0.16' CHECK (iva_rate IN ('0.16', '0', 'exento')),
  ieps_rate           numeric(6,4) NOT NULL DEFAULT 0,
  price_includes_tax  boolean NOT NULL DEFAULT true,
  sat_product_key     text,
  sat_unit_key        text,
  active              boolean NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX product_barcode_idx ON product (store_id, barcode);  -- not unique: duplicated barcodes happen
CREATE INDEX product_name_idx    ON product (store_id, lower(name));

CREATE TABLE product_supplier (
  product_id      uuid NOT NULL REFERENCES product(id),
  supplier_id     uuid NOT NULL REFERENCES supplier(id),
  cost_centavos   integer CHECK (cost_centavos >= 0),
  preferred       boolean NOT NULL DEFAULT false,
  PRIMARY KEY (product_id, supplier_id)
);

-- Purchases from suppliers. Unpaid balance = total - payments, which gives "credit owed".
CREATE TABLE purchase (
  id              uuid PRIMARY KEY,
  store_id        uuid NOT NULL REFERENCES store(id),
  supplier_id     uuid NOT NULL REFERENCES supplier(id),
  received_at     timestamptz NOT NULL DEFAULT now(),
  due_date        date,
  total_centavos  integer NOT NULL CHECK (total_centavos >= 0),
  invoice_ref     text,
  user_id         uuid NOT NULL REFERENCES app_user(id),
  voided_at       timestamptz
);

CREATE TABLE purchase_item (
  id              uuid PRIMARY KEY,
  purchase_id     uuid NOT NULL REFERENCES purchase(id),
  product_id      uuid NOT NULL REFERENCES product(id),
  qty             numeric(12,3) NOT NULL CHECK (qty > 0),
  unit_cost_centavos integer NOT NULL CHECK (unit_cost_centavos >= 0),
  expires_on      date               -- required by the app when product.tracks_expiry
);

CREATE TABLE supplier_payment (
  id              uuid PRIMARY KEY,
  store_id        uuid NOT NULL REFERENCES store(id),
  supplier_id     uuid NOT NULL REFERENCES supplier(id),
  purchase_id     uuid REFERENCES purchase(id),
  amount_centavos integer NOT NULL CHECK (amount_centavos > 0),
  paid_at         timestamptz NOT NULL DEFAULT now(),
  user_id         uuid NOT NULL REFERENCES app_user(id),
  voided_at       timestamptz
);

-- Lots: one row per received batch with an expiry date (FEFO). Only for tracks_expiry products.
CREATE TABLE stock_lot (
  id              uuid PRIMARY KEY,
  product_id      uuid NOT NULL REFERENCES product(id),
  purchase_item_id uuid REFERENCES purchase_item(id),
  expires_on      date NOT NULL,
  qty_remaining   numeric(12,3) NOT NULL CHECK (qty_remaining >= 0),
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX stock_lot_fefo_idx ON stock_lot (product_id, expires_on) WHERE qty_remaining > 0;

-- Append-only ledger of every stock change. Current stock = sum(qty_delta).
CREATE TABLE stock_movement (
  id              uuid PRIMARY KEY,
  store_id        uuid NOT NULL REFERENCES store(id),
  product_id      uuid NOT NULL REFERENCES product(id),
  lot_id          uuid REFERENCES stock_lot(id),
  qty_delta       numeric(12,3) NOT NULL CHECK (qty_delta <> 0),
  reason          text NOT NULL CHECK (reason IN
                    ('purchase', 'sale', 'sale_void', 'return', 'adjustment', 'count', 'waste_expired', 'waste_damaged')),
  ref_id          uuid,                 -- purchase_item, sale line, count, etc.
  note            text,
  user_id         uuid NOT NULL REFERENCES app_user(id),
  device_id       text NOT NULL,
  occurred_at     timestamptz NOT NULL,  -- when it happened on the device (may be offline)
  received_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX stock_movement_product_idx ON stock_movement (product_id, occurred_at);

-- ---------- Views used by the alert screens ----------

CREATE VIEW product_stock AS
SELECT p.id AS product_id, p.store_id, p.name, p.min_stock,
       COALESCE(sum(m.qty_delta), 0) AS on_hand
FROM product p
LEFT JOIN stock_movement m ON m.product_id = p.id
WHERE p.active
GROUP BY p.id;

CREATE VIEW stock_alert AS
SELECT product_id, store_id, name, on_hand, min_stock,
       CASE WHEN on_hand <= 0 THEN 'out_of_stock' ELSE 'low_stock' END AS alert
FROM product_stock
WHERE on_hand <= 0 OR on_hand <= min_stock;

CREATE VIEW expiry_alert AS
SELECT l.id AS lot_id, p.id AS product_id, p.store_id, p.name, l.expires_on, l.qty_remaining,
       COALESCE(p.expiry_warning_days, c.expiry_warning_days, 7) AS warning_days,
       CASE WHEN l.expires_on < (now() AT TIME ZONE 'America/Mexico_City')::date THEN 'expired'
            ELSE 'near_expiry' END AS alert
FROM stock_lot l
JOIN product p ON p.id = l.product_id AND p.tracks_expiry
LEFT JOIN category c ON c.id = p.category_id
WHERE l.qty_remaining > 0
  AND l.expires_on <= (now() AT TIME ZONE 'America/Mexico_City')::date
                      + COALESCE(p.expiry_warning_days, c.expiry_warning_days, 7);

CREATE VIEW supplier_balance AS
SELECT s.id AS supplier_id, s.store_id, s.name,
       COALESCE((SELECT sum(total_centavos) FROM purchase pu
                 WHERE pu.supplier_id = s.id AND pu.voided_at IS NULL), 0)
     - COALESCE((SELECT sum(amount_centavos) FROM supplier_payment sp
                 WHERE sp.supplier_id = s.id AND sp.voided_at IS NULL), 0) AS owed_centavos
FROM supplier s;

-- Suggested order: products from a supplier at or under min_stock, topped up to min_stock + reorder_qty.
CREATE VIEW suggested_order AS
SELECT ps.supplier_id, st.product_id, st.name, st.on_hand, st.min_stock,
       GREATEST(st.min_stock + COALESCE(p.reorder_qty, 0) - st.on_hand, 0) AS suggested_qty
FROM product_stock st
JOIN product p ON p.id = st.product_id
JOIN product_supplier ps ON ps.product_id = st.product_id AND ps.preferred
WHERE st.on_hand <= st.min_stock;

-- ---------- Permissions for the app role ----------
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO pos_app;
REVOKE UPDATE ON stock_movement FROM pos_app;   -- ledger is append-only
GRANT SELECT ON product_stock, stock_alert, expiry_alert, supplier_balance, suggested_order TO pos_app;

COMMIT;
