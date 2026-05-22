# x-fdsnws-event

**x-fdsnws-event** is a reference implementation of a version-aware extension of the
FDSNWS/event access model for reproducible seismic event catalogues.

The project implements a RESTful event service compatible with the FDSNWS/event
query pattern and adds controlled catalogue-maintenance semantics: full-document
updates, logical withdrawals, preserved event revisions, and historical catalogue
snapshots through the `asofdate` query parameter.

The primary goal is not to define a software product as the standard, but to
demonstrate that reproducible catalogue maintenance can be enforced at the API
level.

In this sense, x-fdsnws-event should be read as an executable reference
implementation of a protocol idea: the same public API used to disseminate event
data is also the mandatory boundary through which catalogue data are inserted,
updated, withdrawn, and, where administratively allowed, erased.

---

## Motivation

Conventional seismic event web services usually expose the current state of a
catalogue. The catalogue itself may be maintained elsewhere, by operational
systems, review workflows, database scripts, or manual tools. Once an event is
updated, merged, split, reclassified, or withdrawn, users may no longer be able
to reproduce the exact result of a previous query.

This is especially relevant for seismic catalogues, where preliminary locations,
magnitudes, event types, and phase information may evolve after first
publication. Even small changes can affect scientific analyses, hazard products,
public communications, or published query results.

x-fdsnws-event addresses this by making the event-service API both:

1. the dissemination interface; and
2. the mandatory maintenance boundary.

If all public catalogue changes pass through the API, the service can preserve
complete event versions, close validity intervals, and reconstruct previous
catalogue states.

The result is a reproducibility-oriented event service: users can continue to
query the current catalogue in the usual FDSNWS/event style, while users who need
to reproduce a past catalogue state can add a temporal snapshot parameter.

---

## Core protocol rules

The implementation follows four protocol rules.

### 1. API-only mutations

Public catalogue mutations are performed through controlled API operations:

- insertion;
- full-document update;
- logical withdrawal.

Administrative erasure, where enabled, is exposed only as a restricted operation
for testing, reset, or controlled maintenance of unpublished catalogues. It is
not part of the public reproducibility profile.

This rule is the main operational invariant of the protocol: no public catalogue
change should bypass the controlled API.

### 2. Full-document updates

Updates are submitted as complete QuakeML event documents.

Partial updates are intentionally not part of the protocol, so that every stored
revision is a complete event representation. This avoids ambiguity about which
parts of an event record belong to a given version.

### 3. Immutable version preservation

A new submission creates a new event version and does not overwrite the previous
submitted payload.

The previous active version is closed by validity metadata, while the new version
becomes current.

The event payload of a submitted version is preserved. The service may update
validity metadata, such as the end of the validity interval, but the submitted
version remains historically identifiable as a complete event document.

### 4. Controlled withdrawal

A logical `DELETE` operation closes the validity interval of the active version
without physically deleting historical data.

Withdrawn versions no longer appear in current queries, but remain available to
historical `asofdate` queries for times when they were valid.

Physical erasure is treated separately. It is a restricted administrative
operation for testing, reset, or controlled maintenance, and is outside the
public reproducibility profile.

---

## Historical snapshots with `asofdate`

The `asofdate` query parameter requests the catalogue snapshot visible at a
specified UTC time.

Without `asofdate`, the service returns the current catalogue view.

With `asofdate`, the service:

1. selects the version of each logical event valid at the requested time;
2. applies ordinary query filters to that selected version;
3. applies ordering and pagination;
4. serializes the selected event set.


Example:

```text
/fdsnws/event/1/query?starttime=2023-01-01T00:00:00
  &endtime=2023-01-02T00:00:00
  &minmag=2.0
  &asofdate=2024-01-01T00:00:00Z
```

Conceptually, this asks:

> What would this query have returned from the catalogue state visible at
> `2024-01-01T00:00:00Z`?

The protocol does not require users to know internal revision identifiers in
ordinary use. Users can reproduce a catalogue state by recording the query URL,
the `asofdate` value, and the service/release used to serve the data.

---

## Validity intervals

Each submitted event version has a validity interval.

A version is valid at time `t` when:

```text
start <= t and (endDate is absent or t < endDate)
```

The interval is therefore closed at the start and open at the end.

A current version has no closed end time.

A logically withdrawn event has a closed validity interval and is absent from the
current view, but remains available to historical queries for times before the
withdrawal.

---

## What this implementation is for

x-fdsnws-event is primarily designed for:

- reviewed seismic bulletins;
- observatory catalogue releases;
- reproducible data products;
- public catalogues where revisions and withdrawals must remain auditable;
- scientific workflows that need to reproduce the state of a catalogue at a
  previous time.

The protocol can be applied to real-time catalogues, but the current reference
implementation has not been optimized or validated for strict low-latency
alerting.

Its most natural present use case is the publication and maintenance of revised
catalogues and bulletins, where reproducibility, provenance, and historical
access are more important than ultra-low-latency notification.

---

## What this implementation is not

x-fdsnws-event is not intended to be the only possible implementation of the
protocol.

The same API semantics could be implemented using another backend, including a
relational database, a document store, an object store, or a hybrid architecture,
provided that complete event versions and validity intervals are preserved.

The BaseX implementation in this repository is a working reference
implementation used to validate the protocol semantics.

The implementation is also not presented as a direct replacement for all
real-time earthquake notification systems. Further engineering may be required
for strict low-latency operational alerting or high-throughput real-time
deployments.

---

## Architecture

The service has three logical layers.

### API layer

Exposes standard FDSNWS/event-style query operations and controlled mutation
operations.

The API is both the access interface and the maintenance boundary. Public
catalogue changes are not expected to be performed by direct database writes.

### Persistence layer

Stores complete event documents and version metadata.

Each event version is preserved as a complete document together with metadata
describing its revision and validity interval.

### Logical archival layer

Superseded and withdrawn versions form a logical archive, sometimes referred to
as the Attic.

These versions are excluded from the current view but remain available to
historical `asofdate` queries.

The layers do not need to be physically separated. In the reference
implementation, active, superseded, and withdrawn versions are stored in the same
XML-native database.

---

## Reference implementation

The current implementation uses:

- RESTXQ endpoints;
- BaseX as native XML database;
- QuakeML as the default event-document format;
- an OpenAPI description of the service interface;
- a derived temporal index/cache for lightweight queries;
- pytest-based integration tests.

The temporal index is not the source of truth. It is derived from the versioned
event store and can be rebuilt.

For historical queries, indexed rows are selected by validity interval. For
current queries, only open validity intervals are selected.

Query paths that use the temporal index must still resolve logical events and
avoid returning more than one revision of the same logical event in a single
snapshot.

---

## Query semantics

Historical query evaluation follows this order:

1. **Temporal resolution**  
   Select the current open version or the version valid at `asofdate`.

2. **Attribute filtering**  
   Apply standard filters such as time window, bounding box, depth, magnitude,
   event type, catalogue, contributor, event identifier, and origin identifier.

3. **Ordering and pagination**  
   Sort and page the logical-event result set.

4. **Serialization**  
   Render the selected event set in the requested output format.

The `updatedafter` parameter has different semantics. It filters by update time
and does not reconstruct a catalogue snapshot. For this reason, `asofdate` and
`updatedafter` are treated as mutually exclusive temporal modes.

---

## Supported operations

The exact service interface is documented in the OpenAPI specification included
with the repository.

Typical operations include the following.

### Current or historical query

```http
GET /fdsnws/event/1/query
```

Example current query:

```text
/fdsnws/event/1/query?starttime=2023-01-01&endtime=2023-01-02
```

Example historical query:

```text
/fdsnws/event/1/query?starttime=2023-01-01&endtime=2023-01-02&asofdate=2024-01-01T00:00:00Z
```

### Full-document insertion or update

```http
PUT /fdsnws/event/1/event/?dbname=<DBNAME>&catalog=<CATALOG>&filename=<FILENAME>&upindex=<true|false>
```

The request body is a complete QuakeML event document.

For bulk loading, files can be inserted with `upindex=false`, followed by a
single index rebuild.

### Logical withdrawal

```http
DELETE /fdsnws/event/1/event/?dbname=<DBNAME>&catalog=<CATALOG>&filename=<FILENAME>
```

In history-enabled mode, this closes the validity interval of the active version.

### Administrative erasure

```http
DELETE /fdsnws/event/1/event/?dbname=<DBNAME>&catalog=<CATALOG>&filename=<FILENAME>&erase=true
```

This physically removes versions and is intended only for testing, reset, or
restricted maintenance. It is outside the public reproducibility profile.

### Rebuild event index

```http
GET /fdsnws/event/1/management/eventindex
```

---

## Quick start with Docker Compose

```bash
git clone <REPO_URL>
cd x-fdsnws-event
docker compose up -d
```

Check that the service is reachable:

```bash
curl http://127.0.0.1:8081/fdsnws/event/1/
```

Check configured databases:

```bash
curl -u admin:admin \
  http://127.0.0.1:8081/fdsnws/event/1/management/databases_info
```

---

## Loading QuakeML files

The recommended bulk-loading pattern is:

1. upload all files with `upindex=false`;
2. rebuild the index once after the last file.

Example PUT:

```bash
curl -u admin:admin \
  -X PUT \
  -H "Content-Type: text/xml" \
  --data-binary @20230101-000039__33778101__INGV-EVENT.xml \
  "http://127.0.0.1:8081/fdsnws/event/1/event/?dbname=TestDB_1&catalog=INGV&upindex=false&filename=20230101-000039__33778101__INGV-EVENT.xml"
```

Rebuild the index:

```bash
curl -u admin:admin \
  "http://127.0.0.1:8081/fdsnws/event/1/management/eventindex"
```

A helper script for batch loading may be provided in the repository. It should
validate that target databases exist before uploading, upload files one by one
without index rebuild, and rebuild the event index only at the end.

---

## History-enabled and compatibility modes

The reference implementation supports two modes.

### History enabled

Mutations are version-preserving.

- PUT creates a new version.
- DELETE closes the active version.
- `asofdate` selects a historical snapshot.
- Previous versions remain queryable.

This is the reproducibility profile of the protocol.

### History disabled

The service behaves as a conventional mutable event service.

- PUT overwrites current data.
- DELETE removes data.
- `asofdate` is accepted but ignored.

This mode is outside the public reproducibility profile and is provided for
backward-compatible deployments.

---

## Validation

The validation suite is designed as an executable specification of the protocol
semantics.

It tests externally visible behaviour rather than internal implementation
details.

Covered validation areas include:

- version lifecycle;
- logical withdrawal;
- administrative erasure;
- snapshot reproducibility;
- temporal isolation across revisions;
- logical-event uniqueness;
- multi-event catalogue reconstruction;
- filter semantics after temporal resolution;
- ordering and pagination;
- output-format consistency;
- separation between `asofdate` and `updatedafter`;
- compatibility mode with history disabled.

Representative tests include:

```text
test_history_update_exposes_old_and_new_versions
test_history_delete_hides_current_but_preserves_past_snapshot
test_history_asofdate_reproducibility_is_stable_after_later_changes
test_history_include_flags_apply_to_selected_historical_revision
test_history_broad_query_returns_one_revision_only_per_logical_event
test_history_rejects_asofdate_with_updatedafter
test_history_disabled_ignores_asofdate_and_returns_current_state
```

Run the history validation suite against a running service:

```bash
pytest --host=127.0.0.1:8081 test/test_history_mode.py
```

Run the broader BaseX/API validation suite:

```bash
pytest --host=127.0.0.1:8081 test/test_basex.py
```

Some validation tests may cover implementation-specific text or phase-output
serializers. These formats are not part of the FDSNWS/event standard; they are
used to verify that all supported serializers consume the same temporally
resolved event set.

---

## Reproducibility guarantee

For a fixed service release, configuration, and database state, identical
requests with identical parameters, including `asofdate`, are expected to return
byte-identical or canonically equivalent output, depending on the serialization
format.

The guarantee depends on the operational invariant that all public catalogue
mutations pass through the controlled API.

Direct database modifications bypass the protocol and are outside the guarantee.

---

## FAIR profile

The protocol primarily strengthens FAIR Reusability by preserving provenance,
historical context, and previous catalogue states.

It strengthens Accessibility by allowing earlier catalogue states to be retrieved
through the same service interface used for current access.

It preserves Interoperability by keeping the FDSNWS/event query pattern and
QuakeML serialization as the main access model.

It does not replace external Findability mechanisms such as persistent
identifiers, repository metadata, or data citations. Instead, it complements them
by making service queries themselves reproducible when cited together with
`asofdate`, service release, and endpoint information.

---

## Citation

A manuscript describing the protocol is in preparation.

Until a formal citation is available, cite the archived repository release:

```text
Pintore, S. x-fdsnws-event: version-aware API semantics for reproducible seismic event catalogues. Release <TAG>. DOI: <DOI>.
```

---

## Status

The project is a working reference implementation of the proposed protocol.

It is suitable for testing, validation, and reproducible catalogue-publication
workflows.

Further engineering may be required for strict low-latency operational alerting
or high-throughput real-time deployments.
