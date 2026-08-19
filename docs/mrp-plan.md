# Design plan: MRP from SysML assemblies and a plain-text ledger

**Status:** proposal. Nothing here is implemented. The BOM extraction it
depends on already ships in sysml-cli; the rest is unwritten.

## The idea

An early-stage MRP built from two plain-text stores that already exist for
other reasons:

- **SysML v2 models own the bill of materials** — what goes into what, in
  what quantity. This is the design, and it is already modeled.
- **A plain-text accounting ledger owns inventory state** — what is on
  hand, at what cost, in which lot. Double-entry with commodity lots is a
  better fit for this than it first appears: inventory *is* an asset
  account, and lot tracking is what PTA tools do well.

A script joins them on the part number: explode the BOM, net it against
ledger balances, emit planned orders back into the ledger as forecast
entries.

This is the same split real MRP systems make — engineering BOM versus
inventory subledger — with the database replaced by two text stores that
both diff and both live in git.

### Why it is worth doing

Lot genealogy. If a supplier lot is suspect, the ledger names every work
order that consumed it and every serial that shipped. That query is
expensive to reconstruct from spreadsheets, and it connects directly to
the hazard and traceability machinery already in these libraries: a
nonconformance becomes a query, not an archaeology project.

### Scope limits, stated up front

Good fit for low volume, high mix, traceability-heavy work. Not a fit for
a shop running thousands of inventory movements a day — hledger handles
large journals well, but plain text plus git means effectively one writer
at a time, which breaks down once several people receive stock
concurrently.

The design stays honest as long as it answers only *what do I buy, when,
and which lot went where*. Routings, work centers, capacity planning and
shop-floor control are MRP II and are explicitly out of scope.

## Architecture

The repo's existing rule applies unchanged: **domain semantics live in the
model, generic primitives live in tools.** Three layers, one-way flow:

```
  SysML model  ──sysml view──▶  exploded BOM (JSON)  ──▶  planner  ──▶  ledger
  (the design)                   (a tool primitive)      (the script)   (the state)
```

Two rules make the split hold:

1. **Inventory quantities never enter the SysML model.** The model is the
   design; the ledger is the state. On-hand changes daily, and that churn
   in a `.sysml` file would bury the design history's signal.
2. **The script never writes back into `.sysml` files.** Flow is one-way.

### What already works

No sysml-cli change is needed for the extraction. The `composition` row
provider walks part and item usages, multiplies multiplicity down the tree,
and surfaces any attribute declared on a row's type as a column — without
the tool knowing those attribute names:

```
$ sysml view mrp.sysml MrpBom -f csv
path,type,partNumber,quantity,extended,unitCost,leadTimeDays
topAsm,Module,MOD-1,5,5,,
topAsm.board,Pcb,PCB-MAIN-A,2,10,14.50,
topAsm.board.r,Resistor,RC0805-10K,8,80,0.02,21
topAsm.spare,Resistor,RC0805-10K,3,15,0.02,21
```

`-f json` and `-f csv` are already there. Filtering is a `where` clause:
`where = "partNumber != \"\""` drops geometric features and other
non-material rows; `where = "sourcing == \"buy\""` splits make from buy.
`sysml rollup compute --root Module --attr unitCost` aggregates costs over
the same tree, respecting multiplicity.

### Confirmed limits of the extraction

- **Rows are per path, not per part number.** The resistor above appears
  twice, 80 and 15. Rolling up to 95 is the script's job, or a `groupBy`
  addition to `@TableRendering` — generic enough to be worth doing on its
  own merits, independent of MRP.
- **Attributes resolve on the usage's *type*, not usage-level overrides.**
  `part r : Resistor { attribute :>> unitCost = 0.03; }` will not surface
  as a column.
- **Multiplicity is an integer count.** `0.75 m of wire` cannot come from
  `[n]`. Continuous quantities need a `qtyPer : Real` attribute, and the
  script can apply it correctly only at leaves — which covers the common
  case, since continuous materials (wire, adhesive, sheet) are leaves.
  Teaching the composition walker to honor a real-valued multiplier would
  hardcode a domain attribute name into a generic tool, so it should not
  be done.

## Phase 1 — `libraries/Procurement.sysml`

The vocabulary layer, following the pattern of `Tolerancing` and
`HazardAnalysis`: no tool change, only standard SysML mechanisms.

```
part def Item {
    attribute partNumber : String;
    attribute uom : String default "EA";
    attribute sourcing : Sourcing default Sourcing::buy;
    attribute unitCost : Real[0..1];
    attribute leadTimeDays : Real default 0;
    attribute minOrderQty : Real default 1;
    attribute orderMultiple : Real default 1;
    attribute safetyStock : Real default 0;
    attribute lotControlled : Boolean default false;
}

enum def Sourcing { buy; make; phantom; }
```

`sourcing` is load-bearing: it tells the planner whether to explode through
a node or treat it as a stocked leaf. `phantom` passes requirements through
without stocking — a real MRP concept and cheap to support.

Plus view defs that are just filtered compositions: `MrpBom`,
`PurchasedItems`, `MakeItems`, `LongLead` (`leadTimeDays > 60`),
`CostedBom`.

As elsewhere in this repo, thresholds belong to the model. `LongLead`'s
60 days is a project's judgment, expressed in a `view def` the project
owns, not a flag on a command.

## Phase 2 — the planner

A script — call it `sysml-mrp` — in its own repo. Its only real algorithm
is the netting run; everything else is glue.

Inputs: `sysml view <model> MrpBom -f json`, ledger balances, and a
`demand.yaml` (what to build, how many, need date).

1. Explode the BOM against demand to get gross requirements per part per
   need-date.
2. Compute **low-level codes** — the deepest level each part appears at —
   so parents net before children. A part used at two levels must be
   netted only once, at its deepest.
3. Per part in low-level order:
   `net = gross − onHand − onOrder + safetyStock`
4. Lot-size: `max(minOrderQty, roundUp(net, orderMultiple))`.
   Release date = need date − `leadTimeDays`.
5. A planned order on a `make` part becomes gross requirement on its
   children **at the release date**. That is the recursion, and the reason
   step 2 matters.

Roughly 200 lines. **The ledger must not do this.** Ledgers answer *what
is true, and what was true*; netting is an iterative graph walk with lot
sizing and pegging. The ledger is input (on-hand, on-order) and output
(planned orders), never the planner. Writing netting logic as ledger
queries is the way this design fails.

## Phase 3 — the ledger

**hledger 2.0**, currently in preview. Version 2.0 specifically: its lot
handling is what makes this work, and 1.x is not sufficient.

The lot name is `{YYYY-MM-DD, "LABEL", COST}`, where the quoted label is a
real lot number. Booking is configurable per commodity or per account via a
`lots:` tag, and `SPECID` selects a specific lot via a selector on the
disposal posting. Partial selectors — date and label, cost omitted — are
supported and are the right choice here: stock is issued by lot number,
not by price.

```
commodity RC0805-10K
    lots: SPECID

2026-08-14 * "PO-2291 receipt"  ; Digikey
    assets:inventory:raw:RC0805-10K   1000 RC0805-10K {2026-08-14, "LOT-A4471", $0.021}
    assets:cash                                                          $-21.00

2026-08-20 * "Issue to WO-114"
    assets:inventory:raw:RC0805-10K    -80 RC0805-10K {2026-08-14, "LOT-A4471"}
    assets:inventory:wip:WO-114
```

That second transaction is the genealogy record.

### Booking method comes from the model

The cleanest model-to-ledger mapping in the design. `Item::lotControlled`
generates the commodity's `lots:` tag:

| `lotControlled` | `lots:` | Rationale |
|---|---|---|
| `true` | `SPECID` | Issues must name a lot; genealogy enforced by the ledger |
| `false` | `FIFO` | Cheap consumables where per-lot identity is not worth the bookkeeping |

Never `AVERAGE` — it destroys the genealogy this is being built for.

The `commodity` directives are generated from the BOM view, so the model
decides the booking method and the ledger enforces it.

### Accounts

```
assets:inventory:raw:<PN>      lot-tracked on hand
assets:inventory:wip:<WO>      work order consumption
assets:inventory:fg:<PN>
assets:onorder:<PN>            released, not yet received
expenses:scrap
plan:gross:<PN>                script-generated (virtual)
plan:planned:<PN>              script-generated (virtual)
```

hledger's unbalanced virtual postings let gross requirements be recorded
without inventing a balancing counter-account:

```
2026-09-01 * "Gross requirement WO-114"
    (plan:gross:RC0805-10K)    80 RC0805-10K
```

Time-phasing uses periodic transactions (`~`) with `--forecast` to project
planned orders forward; `--budget` gives plan-versus-actual variance by
period directly.

### Files

- `actual.journal` — real receipts, issues, scrap. Hand-written or fed from
  receiving. Balances honestly.
- `plan.journal` — regenerated wholesale by the script, never hand-edited,
  included only for planning reports.

Every generated entry carries the BOM's git SHA in a tag, so a plan is
reproducible against the model revision that produced it.

### `check lots` as a CI gate

hledger 2.0's `check lots` errors on dispose-before-acquire, ambiguous
selectors, and missing lot cost. Dispose-before-acquire *is* negative
inventory — issuing stock that was never received. Real MRP systems spend
real effort on that guard; here it is one command.

This extends the pattern the repo already uses for `QualityGate` and
`TraceGate`: CI runs `sysml check` against the design and
`hledger check lots` against the state.

## Risks

**hledger 2.0 is a preview** with no announced final date, so the lot
syntax may still move. Mitigation: put all directive emission behind a
single writer module in the script and never hand-edit generated files. A
syntax change then costs one function.

**Lot subaccounts have limited balance-assertion support** — assertions are
checked correctly only if every posting to a lot names the subaccount
explicitly. Machine-generated postings satisfy this trivially; hand-written
ones drift. Generated-not-handwritten is load-bearing here, not just tidy.

**Part numbers must be valid commodity symbols.** Real part numbers with
lowercase letters, `/`, or `#` need deterministic normalization, with the
true part number preserved as metadata on the `commodity` directive.

**Scope creep into MRP II** is the largest risk, and the only mitigation is
the scope limit stated at the top.

## Open questions

- Is `groupBy` worth adding to `@TableRendering`? It would serve cost
  rollups and supplier counts as well as BOM summarization, so it should be
  justified generically or not at all.
- Reference designators (R1, R2, …) matter for electronics BOMs and have no
  home in the current composition model. Probably out of scope; worth
  confirming before the first EDA-adjacent user asks.
- BOM effectivity. The ledger is time-stamped but the BOM is a snapshot at
  git HEAD. Stamping the SHA covers reproducibility, but not "which
  revision was effective on the date this order was released."
