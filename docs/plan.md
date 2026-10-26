# Plan: POS para tienda de abarrotes

Oct 14, 2026 · Gerry

> Snapshot of the living plan doc exported on 2026-10-26. The doc is the source of truth: https://claude.ai/code/artifact/eeec6e55-1ff4-4376-b70c-00aa2b36ada1

## Summary

Start with a Spanish-language, offline-first web POS that does four things well: fast scanning checkout (including sales by weight and loose units), cash drawer cut (corte de caja), fiado tabs per customer, and simple inventory with supplier restocking. Phone recharges, service payments and CFDI invoicing come later, through third-party providers, because each needs a commercial contract and adds regulatory weight.

The first build step is a working checkout screen against a seeded product catalog, tested in a real store on a tablet with a USB or Bluetooth scanner and a 58 mm thermal printer.

## Pilot store: Abarrotes Anny

The pilot is Abarrotes Anny, C. Aldama 16, La Piedad, 54965 Tultepec, Edo. Méx. It runs on a PC, so the supported setup is Chrome on Windows with a USB scanner and a USB thermal printer.

The store already has a [Google Maps listing](https://maps.app.goo.gl/WyLaVxVsKRadLgZKA), but it needs to be claimed and filled in. Action items for its online presence:

- [ ] Claim and verify the existing listing as a Google Business Profile, then check its name, address and category (tienda de abarrotes).
- [ ] Add store photos: the front, the counter and the shelves.
- [ ] Add opening hours (to collect from the owner).
- [ ] Build a simple store website alongside the app, and link it from the Google profile.
- [ ] Add a phone or WhatsApp number to the profile and website.

## How a tienda de abarrotes operates

The tiendita is a one-counter, high-volume, low-ticket business: one to three people sell many small items to neighbors who come several times a day. INEGI's DENUE 2025 counts about 1.09 million abarrotes and food micro-businesses with 1 to 10 employees ([Emprendedor, citing DENUE](https://emprendedor.com/5-habitos-tiendas-de-abarrotes-crecer-servicios-digitales/)). What the software must respect:

| Area | How it works in practice | What it means for the app |
| --- | --- | --- |
| Products | Refrescos, botanas, pan, lácteos, huevo, abarrotes secos (arroz, frijol, aceite, azúcar), limpieza, cigarros, cerveza where licensed. Most carry an EAN-13 barcode; many fresh or bulk items don't. | Barcode lookup must be instant. Items without barcode need quick buttons or a short search. |
| Loose and weighed sales | Cigarros sueltos, huevo by piece or by kilo, frijol, azúcar, jamón and queso by weight, croquetas a granel. | Quantity accepts decimals (kg) and fractions of a pack. A product can be sold by unit, by pack and by weight, each with its own price. |
| Fiado (credit) | Trusted neighbors buy on a tab and pay on payday. Today it is a paper notebook. | Per-customer tab with a balance, credit limit, partial payments and a printable or WhatsApp-able statement. |
| Cash | Almost all sales are cash; change in coins is a constant problem. Card terminals (Mercado Pago Point, Clip) and SPEI transfers are growing. | Fast cash entry with change calculation, mixed payments, and a daily corte de caja that reconciles expected vs counted cash. |
| Recargas and servicios | Phone top-ups (Telcel, AT&T, Movistar, Bait) and bill payments (CFE, water, cable, gift cards) bring traffic and a small commission. Networks such as [tapi, which bought Arcus's Mexican payments business](https://eleconomista.com.ar/negocios/conquista-mexicana-tapi-queda-red-pagos-mas-grande-pais-n86116/amp), resell this through APIs. | Needs a contract with an aggregator; the POS records it as a sale with a commission, not as inventory. Later phase. |
| Suppliers | Route salespeople (preventa) from Bimbo, Coca-Cola/FEMSA, Sabritas, Grupo Modelo, Lala visit on fixed weekdays; dry goods come from a central de abasto or mayoristas such as Sam's or Abarrotera. Bottle deposits (envase) for refrescos and cerveza are common. | Purchase entry by supplier with cost, an "order day" per supplier, low-stock list, and envase tracking. |
| Taxes and SAT | Most owners are in RESICO or another simplified regime; few customers ask for a factura. Sales without a customer RFC are rolled into a factura global to público en general with the generic RFC, uso S01 and régimen 616, listing ticket folios ([IDC](https://idconline.mx/fiscal-contable/2022/06/29/cfdi-40-por-operaciones-con-publico-en-general)). Many basic foods are IVA 0%; refrescos, botanas and cigarros carry IEPS. | Each product needs IVA and IEPS rates from day one, and every ticket needs a folio, so invoicing can be added later without rework. Stamping goes through a PAC. |
| Devices | Cheap PC or Android tablet, USB or Bluetooth barcode scanner (acts like a keyboard), 58 mm or 80 mm ESC/POS thermal printer, cash drawer triggered by the printer, sometimes a counter scale. | Scanner works out of the box in a web app. Printer, drawer and scale need a small bridge (see Hardware). |

The periodicity and deadline of the factura global, and IEPS rates by product, should be confirmed with the owner's accountant before the invoicing phase.

## MVP scope

The MVP is done when one real store can run a full day of sales, close the drawer and know what to restock, with the internet unplugged.

In the MVP:

1. **Venta (checkout).** Scan or search, quick buttons for top items without barcode, quantity by unit or kilo, line discount, cancel line, park a sale and resume it. Target: a scanned item appears in under 200 ms.
2. **Cobro.** Cash with change calculation and coin shortcuts ($20, $50, $100, $200, $500), card or transfer recorded as reference only, mixed payment, and "a cuenta" (fiado).
3. **Ticket.** Print on a 58/80 mm thermal printer with store name, folio, items, total and payment, and open the cash drawer.
4. **Fiado.** Customers with name and phone, credit limit, balance, abonos, and a statement to share by WhatsApp.
5. **Caja.** Opening float, cash in/out movements (paying a supplier from the drawer), and corte de caja: expected vs counted, by payment method.
6. **Productos e inventario.** Catalog with barcode, price, cost, unit type, IVA/IEPS rates, category and minimum stock. Stock goes down with each sale and up with each purchase. CSV import so the owner does not type 1,500 products by hand.
7. **Compras.** Record a supplier delivery with costs; low-stock list grouped by supplier.
8. **Usuarios.** Owner and cashier roles; cashier cannot change prices, delete sales or see profit.
9. **Reportes básicos.** Sales by day, top products, gross margin, and fiado owed.

Out of the MVP, on purpose: recargas and service payments, CFDI invoicing, scale integration, multiple stores, card terminal integration, loyalty and online orders.

## Suppliers, stock and alerts

Supplier and stock management is part of the MVP, with two alerts: low stock and close to expire. Gerry added this on Oct 17, 2026. The alerts show inside the app when the shift opens. Sending them by WhatsApp waits for phase 2, when the server is online.

**Suppliers.** Each supplier has a name, a contact, a WhatsApp number, visit days and payment terms (cash or credit days). It also lists the products it delivers, with the supplier's code, pack size and last cost. Before a route salesperson's visit, the app suggests an order: every product from that supplier below its minimum, rounded up to full packs. Purchases bought on credit show as an amount owed to that supplier until they are paid.

**Stock.** Stock goes down with each sale and up with each purchase. Physical counts and mermas (damaged, expired or stolen goods) are recorded as adjustments with a reason. Every change keeps who made it and when.

**Expiry dates.** Every edible product tracks expiry, which Gerry decided on Oct 17, 2026. Non-food items, such as cleaning products and medicine, can opt in with "controla caducidad". When a delivery is received, the cashier types the expiry date for those lines. Each delivery becomes a lot with its own date and quantity. Sales use up the lot that expires first (FEFO) automatically, so the cashier never picks a lot. The counts are approximate unless the shelves are also rotated by date.

| Alert | When it fires | What the owner sees |
| --- | --- | --- |
| Agotado (out of stock) | Stock is 0 or less | Red badge and the top of the restock list |
| Stock bajo (low stock) | Stock is at or below the product's minimum | Restock list grouped by supplier, added to the suggested order |
| Por caducar (close to expire) | A lot expires within the product's alert days (default 7, 3 for dairy and bread) | List with quantity and days left, and actions: discount it, return it to the supplier, or record it as merma |
| Caducado (expired) | A lot's date has passed with units left | Warning when that product is scanned, and a prompt to record it as merma |

**Data model additions:** `supplier` gains contact, whatsapp and credit\_days. New `supplier_product` (supplier\_id, product\_id, supplier\_code, pack\_qty, last\_cost). `product` gains tracks\_expiry and expiry\_alert\_days. New `product_lot` (product\_id, purchase\_line\_id, expires\_on, qty\_received, qty\_remaining). New `supplier_payment` (supplier\_id, purchase\_id, amount, method, paid\_at).

Open question: how many days of warning does each category need?

## Security and theft

The store was robbed earlier in 2026, so the app should reduce how much a theft can take and make every loss traceable. The software cannot stop a robbery, and staff safety always comes first. Cameras, lighting and keeping little cash on hand do most of the work, and the app supports them.

| Feature | What it does | Phase |
| --- | --- | --- |
| Cash limit in the drawer | When the drawer passes a set amount (for example $2,000), it prompts a retiro to a safe and records it. A robbery then takes less. | MVP |
| Audit of risky actions | Logs every cancelled sale, deleted line, discount, price change and drawer opened without a sale, with cashier and time. The owner sees a daily summary. | MVP |
| Stock discrepancy check | Compares physical counts with expected stock and flags products that keep going missing, such as cigarettes, liquor and razors. | MVP |
| Data safe if the PC is stolen | PIN lock after a few minutes idle, and sales synced to the server, so nothing is lost with the PC. | MVP (sync once the server runs) |
| Silent panic button | A discreet key or button sends an alert with the store address to the owner and chosen contacts by WhatsApp or SMS. It shows nothing on screen. | Phase 2 (needs the server online) |
| Camera timestamps | Each sale, cancellation and drawer opening keeps an exact time, so the owner can find it in camera footage. | MVP; a camera link later |

The municipality or state may offer a link to the C5 emergency center for businesses. That is inferred, not checked, so ask locally in Tultepec.

## Customer app

A customer app for ordering ahead and getting promotions becomes a new phase 5, after the POS works and the server is online. It needs the live catalog and stock from the POS, so it cannot start earlier.

1. **Start on the store website.** Make it an installable web app (PWA): customers browse products with prices and availability, build an order, and pick a pickup time or delivery. The store sees new orders on the POS, prepares them and charges at pickup. This avoids app store costs and reviews.
2. **Promotions and loyalty.** Customers sign up with their phone number. They get weekly offers by WhatsApp or notification, and earn points recorded at the counter. Promotions come from POS data, such as products close to expiry or slow sellers.
3. **Native app later.** Publish to Google Play first, since most customers use Android, and the App Store only if adoption justifies it.

Online payment and delivery logistics are open questions for that phase. Paying at pickup is the default.

## Phases after the MVP

Four phases, each unlocked by a real-store result rather than a date. Invoicing and recargas wait until the daily tool is trusted, because both need outside contracts (a PAC and a payments aggregator).

_(The roadmap chart with 4 phases and 3 gates lives in the [plan doc](https://claude.ai/code/artifact/eeec6e55-1ff4-4376-b70c-00aa2b36ada1).)_

Phase 2 makes the counter faster (scale, weighed labels, card terminal, a second device). Phase 3 adds CFDI 4.0 through a PAC, including invoicing a past ticket and the factura global. Phase 4 adds recargas and service payments, supplier orders and more stores.

## Suggested tech stack

Build an installable PWA that keeps the whole store's data on the device and syncs to a cloud backend when the connection allows. Neighborhood internet is unreliable, and a POS that stops selling when the modem drops will be abandoned in a week.

| Layer | Choice | Why |
| --- | --- | --- |
| Front end | React + TypeScript, Vite, Tailwind | Large ecosystem, easy to hire for, fast touch UI on cheap tablets. |
| Offline storage | IndexedDB via Dexie.js | Local catalog search and sales keep working with no network. |
| Sync | Outbox of local events pushed to the server; server pushes catalog changes back | Simple and debuggable for one store; can grow to several devices. |
| Backend | Node.js (Fastify or NestJS) + PostgreSQL, or Supabase to start faster | Postgres handles money and reporting well; Supabase gives auth and hosting with little setup. |
| Money | Integer centavos everywhere, never floats | Avoids rounding errors in totals, IVA and cortes. |
| Printing and drawer | ESC/POS over WebUSB or Web Serial in Chrome; a tiny local print bridge as fallback | Browsers cannot print raw ESC/POS by default; the drawer opens through the printer's kick pulse. |
| Hosting | Vercel or Cloudflare Pages for the PWA; Railway, Render or Supabase for the API | Low cost for a single store. |
| Later: CFDI | A PAC with a REST API (e.g. Facturama, SW Sapien, Finkok) | Avoids implementing XML signing and SAT certification ourselves. |
| Later: recargas | An aggregator API (e.g. tapi, Prontipagos) | Requires a commercial contract and a prepaid balance. |

The UI is Spanish only for now, with all labels in one locale file so English can be added later. Prices format as MXN with `es-MX`.

## Data model sketch

About sixteen tables cover the MVP. Sales, payments and stock movements are append-only: a mistake is fixed with a cancellation or adjustment row, never an edit, so the corte and inventory always add up. All money is in centavos; quantities are decimals to 3 places for kilos.

| Table | Key fields | Notes |
| --- | --- | --- |
| store | id, name, rfc, regimen\_fiscal, cp, ticket\_header | One row now; ready for more stores. |
| user | id, store\_id, name, pin\_hash, role (owner, cashier) | PIN login at the counter. |
| product | id, name, category\_id, sale\_unit (pieza, kg, litro), price, cost, iva\_rate, ieps\_rate, sat\_clave\_prod\_serv, sat\_clave\_unidad, min\_stock, active | SAT keys can be blank until invoicing. |
| product\_barcode | product\_id, barcode, pack\_qty, price\_override | One product, many barcodes: single can vs 6-pack. |
| category | id, name, quick\_button\_order | Drives the quick-button grid. |
| customer | id, name, phone, credit\_limit, balance, rfc?, notes | balance is a cached sum of fiado\_movement. |
| sale | id, folio, register\_session\_id, user\_id, customer\_id?, created\_at, subtotal, iva, ieps, total, status (completed, cancelled), invoiced\_cfdi\_id? | folio is sequential per store. |
| sale\_line | sale\_id, product\_id, qty, unit\_price, discount, iva, ieps, line\_total | Prices copied at sale time. |
| payment | sale\_id, method (efectivo, tarjeta, transferencia, fiado), amount, received, change | Several per sale for mixed payment. |
| fiado\_movement | customer\_id, sale\_id?, type (cargo, abono), amount, created\_at, user\_id | Ledger behind each tab. |
| register\_session | id, user\_id, opened\_at, opening\_float, closed\_at, counted\_cash, expected\_cash | One per shift; the corte closes it. |
| cash\_movement | register\_session\_id, type (entrada, salida), amount, reason | Paying a supplier from the drawer, etc. |
| supplier | id, name, phone, visit\_days | Bimbo on Tuesday and Friday, etc. |
| purchase / purchase\_line | supplier\_id, created\_at, total; product\_id, qty, unit\_cost | Raises stock and updates cost. |
| stock\_movement | product\_id, qty\_delta, reason (sale, purchase, adjustment, merma), ref\_id, created\_at | Stock on hand = sum of deltas, cached on product. |

Every row also carries a client-generated UUID, a device\_id and an updated\_at, so offline devices can create records without clashing and sync them later.

## Hardware notes

A working counter costs roughly what a mid-range phone does, and the app should run on whatever the owner already has.

| Device | Recommendation | Integration |
| --- | --- | --- |
| Screen | Android tablet 10" or any Windows PC with Chrome | PWA installed to the home screen; landscape layout with large touch targets. |
| Barcode scanner | USB or Bluetooth 1D/2D scanner in keyboard mode | No driver: it types the code plus Enter, and the checkout field listens for it. The phone or tablet camera works as a backup. |
| Ticket printer | 58 mm or 80 mm ESC/POS thermal (USB or Bluetooth) | ESC/POS commands over WebUSB, Web Serial or Web Bluetooth in Chrome; fallback to the browser print dialog with a ticket-sized layout. |
| Cash drawer | RJ11 drawer connected to the printer | Opened by the printer's ESC/POS pulse command, so no separate driver. |
| Scale (phase 2) | Counter scale with RS-232/USB output, or a label scale | Read weight over Web Serial; or scan label-scale barcodes with the price or weight embedded in an EAN-13 starting with 2 ([GS1 variable measure](https://www.gs1uk.org/how-to-barcode-variable-measure-items)). |
| Card terminal | Mercado Pago Point or Clip, standalone | MVP records the method and reference only; integrate later through the provider's API ([Mercado Pago Point for POS](https://www.mercadopago.com.mx/developers/es/docs/mp-point-legacy/integration-configuration/integrate-with-pdv/introduction)). |

WebUSB and Web Serial work in Chrome and Edge but not Safari or Firefox, so the supported setup is Chrome on Android or Windows. iPads would need the local print bridge.

## Risks and open questions

The biggest risk is a checkout slower than the paper notebook; every screen should be tested against a real cashier serving a line.

- **Speed and simplicity.** Owners compare against mental math and a calculator. Measure seconds per sale in the pilot.
- **Catalog loading.** Typing 1,500 products kills adoption. Offer CSV import and "create on scan": an unknown barcode opens a 3-field form.
- **Offline data loss.** A tablet that breaks takes unsynced sales with it. Sync every few minutes when online and show the last sync time.
- **Tax details.** IVA and IEPS rates per product, and the factura global rules, must be checked with the store's accountant before phase 3.

Questions for you:

1. Is this for one specific store you know? Answered: yes, the pilot is Abarrotes Anny.
2. What device does the store have? Answered: a PC.
3. Do they sell by weight today (jamón, queso, granel), and do they own a scale?
4. Do they already sell recargas, and through which provider?

## How to start this week

- [ ] Create the repository: Vite + React + TypeScript PWA, Dexie, Tailwind, Spanish locale file.
- [ ] Define the local schema (product, product\_barcode, sale, sale\_line, payment) and seed 200 common abarrotes products with real barcodes.
- [ ] Build the checkout screen: scan field, cart, totals, cash payment with change.
- [ ] Print a ticket to a 58 mm ESC/POS printer from Chrome.
- [ ] Add register session and corte de caja.
- [ ] Put it in front of the store owner for one afternoon and write down every hesitation.
