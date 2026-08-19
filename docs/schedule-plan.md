# Design plan: project schedules from SysML, scheduled by TaskJuggler

**Status:** proposal. No library code is written. The one sysml-cli
prerequisite — successions retaining their endpoints, and a
`relation:succession` row provider — is done (see *Prerequisite* below).

## The idea

Tasks live in a **separate plan file** that imports the design model, so
schedule churn never touches the architecture. Each task can reference the
requirement, part, or verification it delivers. A generator emits a
TaskJuggler fragment; TaskJuggler computes the schedule and renders it.

The value is not the Gantt chart — every PM tool has one. It is the set of
questions no PM tool can answer, because no PM tool has the design:

- Which tasks close requirement `SF-01`?
- This part changed; what scheduled work is affected?
- Which critical-path tasks have no verification linked?
- **Does every requirement have a task that delivers it?** A coverage gate
  in exactly the `TraceGate` pattern.

Because the plan file `import`s the model, `sysml check` validates those
references. A task pointing at a deleted requirement is an *error*, not a
dangling string in a ticket. That referential integrity is the real
advantage over the incumbent tools — more than the modeling itself.

## The load-bearing decision: partition, not parity

The obvious failure mode is chasing feature parity with TaskJuggler's
project-management syntax and dragging resources, calendars, and timesheets
into SysML. That would be a large modeling effort producing a worse version
of what TaskJuggler already does well.

**Do not seek parity. Define a seam.** The rule:

> A concept belongs in the model only if it references a design artifact or
> is referenced by one.

Resources, shifts, and vacations have no design referent — they stay in
TaskJuggler. The duration of a design activity does have one: it is a
property of the work, and it drives when a requirement can be delivered.

| Model-owned (generated) | TaskJuggler-owned (never modeled) |
|---|---|
| Task identity and tree | Resources, rates, shifts |
| `duration` / `length` / `effort` | Vacations, working hours, calendars |
| Dependencies, type, and lag | Scenarios (plan vs actual), bookings, timesheets |
| Milestones tied to design events | `complete`, leveling `limits`, `chargeset` |
| Links to requirements / parts / verifications | Currency, timezone, `now`, all reports |

When someone asks for `vacation` in the model, the answer is no.

### Dates are outputs, not inputs

TaskJuggler *computes* start and end from duration, dependencies, resources,
and calendars. If the model also carried dates there would be two sources of
truth, disagreeing the moment anything slipped — and the temptation to write
computed dates back into `.sysml`, which breaks the one-way flow that keeps
the plan file safe.

The model holds **constraints**: duration or effort, dependency edges,
resource-free work content, and hard dates *only* where genuinely fixed (a
contractual milestone, a regulatory submission). TaskJuggler holds
**results**: computed dates, critical path, slack, leveled assignments.

## The seam: `include`, `supplement`, `extend`

TaskJuggler has three features that make this composition work, and they are
the reason this integration is better supported than it first appears.

```
project.tjp          PM-owned
  ├─ resources.tji   PM-owned:  resources, rates, shifts, calendars
  ├─ tasks.tji       GENERATED: task tree, durations, dependencies, links
  ├─ actuals.tji     PM-owned:  supplement task X { complete 60, allocate dev1 }
  └─ reports.tji     PM-owned
```

The main file takes a `.tjp` suffix; included files must be `.tji`.

**`supplement`** is the critical piece. It adds attributes to an
already-defined task from another file, so the project manager attaches
`allocate`, `complete`, `booking`, `priority`, and `flags` to generated
tasks *without editing the generated file*. Regeneration never clobbers
their work, and the model never learns what a timesheet is.

**`extend`** carries the traceability into TaskJuggler as first-class,
reportable attributes:

```tjp
extend task {
    reference Req  "Requirement"
    text      Part "Part"
}
```

The project manager sees requirement IDs as a column on their own Gantt
without touching SysML.

## Reuse `succession` — do not invent predecessors

SysML v2 already has `succession` and `first X then Y`, and sysml-cli parses
both. The library must not define its own predecessor connection.

What is genuinely missing, and what the library should add:

- **Dependency type.** `succession` is finish-to-start. Start-to-start,
  finish-to-finish and start-to-finish need a `metadata def` on the
  succession, mapping to TaskJuggler's `onstart` / `onend`.
- **Lag**, in both flavors (below).
- **Work content**: duration, length, effort.
- **The links** to requirements, parts, and verifications.

### Prerequisite: the succession endpoint bug (fixed)

Named successions used to lose their endpoints entirely:

```
succession s1 first design then build;
```
```json
{ "kind": "succession", "name": "s1", "type_ref": null, "parent_def": "Program" }
```

Source and target were gone. They survived only in the *unnamed* form, where
the parser stored them in the `name` and `type_ref` fields — overloading that
collapsed as soon as the succession was named. There was also no
`relation:succession` row provider, so the dependency graph was unreachable
from `sysml view` in every form.

Fixed in sysml-cli: `Usage` gained real `source` and `target` fields, all
three declaration forms populate them, and `relation:succession` exposes the
edges with a `<Type>` filter that closes over specialization:

```
$ sysml view plan.sysml SuccessionTable -f csv
succession,type,source,target,parent
s1,,a,b,Prog
,,b,c,Prog
s2,StartToStart,c,d,Prog
```

Typing a succession is how a project declares its dependency kind, and
`relation:succession:Dependency` selects on it. Endpoints may be feature
chains (`first a.inner then b.inner`), and a succession's *type* is never
mistaken for an endpoint.

Task attributes already worked — `rows = "type:EngTask"` surfaces `duration`
— so extraction now matches the BOM story end to end.

## Edge cases that survive the partition

The seam removes most of the impedance mismatch. These remain, and should be
designed for rather than discovered:

1. **No date literal in SysML.** A fixed milestone date becomes a `String`.
   `sysml check` cannot validate it, so a typo surfaces as a TaskJuggler
   parse error at generation time rather than a model error. The generator
   must validate dates and fail loudly. This is a real loss of the
   model-level checking these libraries otherwise provide.

2. **Three duration concepts, one number type.** TaskJuggler distinguishes
   `duration` (calendar time), `length` (working days), and `effort`
   (person-days). They are not interchangeable, and collapsing them into a
   single `duration : Real` silently corrupts the schedule. The library
   needs three distinct attributes.

3. **The same trap in dependency gaps.** `gapduration` is calendar time,
   `gaplength` is working days. Two attributes, not one.

4. **Relative dependency paths.** TaskJuggler's `!prev` and `!!other.task`
   scoping versus SysML's qualified names. Mechanical to resolve, but nested
   task trees are where the generator's bugs will live.

5. **Multi-valued links flatten.** A task delivering three requirements
   becomes one delimited `extend text`. TaskJuggler is the deliberately
   lossy side; the model keeps the structure and is where such queries
   belong anyway.

## Where the seam leaks

Task *structure* is generated. If the project manager discovers during
resource leveling that a task needs splitting, they cannot do it in
TaskJuggler — the model has to change.

Whether `supplement` can add *child* tasks, rather than only attributes,
determines how much structural freedom they retain. The documentation
promises attributes only. **Test this before committing to the design**: it
is the difference between a self-sufficient project manager and one who
files a ticket against the model every time the plan refines.

## Scope

Good fit where the modeler and the planner are the same person or the same
small team, which is also where the rest of this toolchain aims. The
original concern — that a project manager would have to learn SysML — is
weaker than it looks, since a TaskJuggler user is already authoring a
declarative text format; the marginal cost is task declarations in a second
syntax, and `supplement` means they keep authoring everything else in the
one they know.

Out of scope: earned value management, portfolio-level resource contention
across projects, and anything requiring actuals in the model.

## Open questions

- Does `supplement` accept nested task definitions? Determines the leak
  above.
- Should the coverage gate ("every requirement has a delivering task") be a
  `constraint` in the library, following `QualityGate` and `TraceGate`, or a
  view whose emptiness is the passing result, following `GapCapability`?
- Critical path is a forward pass and a backward pass — roughly a hundred
  lines. Worth computing natively in sysml-cli so `sysml` can answer
  scheduling questions without TaskJuggler installed, or is that duplicating
  the dependency for marginal gain? Resource leveling is the genuinely hard
  part and is not worth reimplementing either way.
