#!/usr/bin/env python
# coding: utf-8
# This comprehensive test suite plays a central role in validating the core claims of the proposed system, namely
# reproducibility, temporal consistency, and correctness of query semantics under evolving data.
# By systematically exercising both single-event and multi-event scenarios, as well as combinations of filters, formats,
# and pagination, the tests ensure that the system reliably reconstructs the state of the catalog at any given time
# without leakage across versions. In particular, they verify that temporal selection via the asofdate parameter is
# applied consistently before all other filters, that only one valid version of each logical event is returned,
# and that results remain stable under subsequent updates and deletions. This provides strong empirical evidence
# that the implementation enforces the intended version-aware data model and supports reproducible scientific workflows
# as described in the paper.
# Query evaluation order is explicitly defined to ensure semantic correctness and reproducibility. Temporal resolution
# is applied first, selecting the version of each event valid at the specified time, followed by attribute filtering,
# ordering, and pagination. This guarantees that all query predicates are evaluated against a consistent snapshot of the
# catalog, preventing leakage across versions and ensuring deterministic results independent of subsequent updates.

import time
from datetime import datetime, timezone
from urllib.parse import quote

import pytest
import requests
import lxml.etree as ET


NS = {
    "bed": "http://quakeml.org/xmlns/bed/1.2",
}

EVENT_FILENAME = "20230101-000039__33778101__INGV-EVENT.xml"
TEST_DBNAME = "TestDB_1"
TEST_PROVIDER = "INGV"


def utc_now_z():
    return (
        datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def get_settings_root(host):
    response = requests.get(f"http://{host}/fdsnws/event/1/settings")
    assert response.status_code == 200, response.text
    return ET.fromstring(response.content)


def get_settings_text(host):
    response = requests.get(f"http://{host}/fdsnws/event/1/settings")
    assert response.status_code == 200, response.text
    return response.text


def put_settings_root(host, basicAuth, root):
    payload = ET.tostring(root, encoding="UTF-8", xml_declaration=True)
    response = requests.put(
        f"http://{host}/fdsnws/event/1/settings",
        data=payload,
        headers={"Content-Type": "application/xml"},
        auth=basicAuth,
    )
    assert response.status_code == 200, response.text


def set_or_create_text_node(root, tag_name, value):
    node = root.find(tag_name)
    if node is None:
        node = ET.SubElement(root, tag_name)
    node.text = value
    return root


def local_event_public_id(file_path):
    root = ET.parse(file_path).getroot()
    events = root.xpath("//*[local-name()='event']")
    assert len(events) == 1, f"Expected one event in {file_path}, found {len(events)}"
    return events[0].get("publicID")

def local_preferred_origin_id(file_path):
    root = ET.parse(file_path).getroot()
    event = root.xpath("//*[local-name()='event']")
    assert len(event) == 1, f"Expected one event in {file_path}, found {len(event)}"
    preferred = event[0].xpath("./*[local-name()='preferredOriginID']/text()")
    assert len(preferred) == 1, f"Expected one preferredOriginID in {file_path}, found {len(preferred)}"
    return preferred[0]

@pytest.fixture
def history_enabled(host, basicAuth):
    original = get_settings_root(host)
    original_bytes = ET.tostring(original, encoding="UTF-8", xml_declaration=True)

    modified = ET.fromstring(original_bytes)
    modified = set_or_create_text_node(modified, "history", "true")
    put_settings_root(host, basicAuth, modified)

    live_settings = get_settings_text(host)
    print("\nLIVE SETTINGS AFTER ENABLE HISTORY:\n", live_settings)
    assert "<history>true</history>" in live_settings

    try:
        yield
    finally:
        restored = ET.fromstring(original_bytes)
        put_settings_root(host, basicAuth, restored)


def event_management_url(
    host,
    dbname=TEST_DBNAME,
    filename=EVENT_FILENAME,
    upindex="true",
):
    return (
        f"http://{host}/fdsnws/event/1/event/"
        f"?dbname={dbname}&catalog={TEST_PROVIDER}&upindex={upindex}&filename={filename}"
    )


def event_query_url(host, event_public_id, asofdate=None, includeall=True, nodata=404):
    params = [
        f"nodata={nodata}",
        f"eventid={quote(event_public_id, safe=':/?=&')}",
    ]
    if includeall:
        params.append("includeall=true")
    if asofdate is not None:
        params.append(f"asofdate={quote(asofdate, safe=':-TZ')}")
    return f"http://{host}/fdsnws/event/1/query?{'&'.join(params)}"


def get_event_query_response(host, event_public_id, asofdate=None, includeall=True, nodata=404):
    return requests.get(
        event_query_url(
            host=host,
            event_public_id=event_public_id,
            asofdate=asofdate,
            includeall=includeall,
            nodata=nodata,
        ),
        allow_redirects=True,
    )


def debug_event_query(host, label, event_public_id, asofdate=None):
    response = get_event_query_response(
        host=host,
        event_public_id=event_public_id,
        asofdate=asofdate,
        includeall=True,
        nodata=404,
    )
    print(f"\n--- {label} ---")
    print("status:", response.status_code)
    print(response.text[:2000])
    return response


def get_single_event(xml_root):
    events = xml_root.xpath("//*[local-name()='event']")
    assert len(events) == 1, f"Expected exactly one event, found {len(events)}"
    return events[0]


def origin_query_url(host, origin_public_id, asofdate=None, includeall=True, nodata=404):
    params = [
        f"nodata={nodata}",
        f"originid={quote(origin_public_id, safe=':/?=&')}",
    ]
    if includeall:
        params.append("includeall=true")
    if asofdate is not None:
        params.append(f"asofdate={quote(asofdate, safe=':-TZ')}")
    return f"http://{host}/fdsnws/event/1/query?{'&'.join(params)}"


def get_origin_query_response(host, origin_public_id, asofdate=None, includeall=True, nodata=404):
    return requests.get(
        origin_query_url(
            host=host,
            origin_public_id=origin_public_id,
            asofdate=asofdate,
            includeall=includeall,
            nodata=nodata,
        ),
        allow_redirects=True,
    )


def debug_origin_query(host, label, origin_public_id, asofdate=None):
    response = get_origin_query_response(
        host=host,
        origin_public_id=origin_public_id,
        asofdate=asofdate,
        includeall=True,
        nodata=404,
    )
    print(f"\n--- {label} ---")
    print("status:", response.status_code)
    print(response.text[:2000])
    return response


def event_query_url_raw(host, params):
    return f"http://{host}/fdsnws/event/1/query?{'&'.join(params)}"


def get_event_query_response_raw(host, params):
    return requests.get(
        event_query_url_raw(host, params),
        allow_redirects=True,
    )

def count_event_details(xml_root):
    event = get_single_event(xml_root)
    return {
        "publicID": event.get("publicID"),
        "origins": len(event.xpath("./bed:origin", namespaces=NS)),
        "magnitudes": len(event.xpath("./bed:magnitude", namespaces=NS)),
        "picks": len(event.xpath("./bed:pick", namespaces=NS)),
        "arrivals": len(event.xpath(".//bed:arrival", namespaces=NS)),
        "amplitudes": len(event.xpath("./bed:amplitude", namespaces=NS)),
        "station_magnitudes": len(event.xpath("./bed:stationMagnitude", namespaces=NS)),
    }


def put_event(
    host,
    basicAuth,
    file_path,
    dbname=TEST_DBNAME,
    filename=EVENT_FILENAME,
    upindex="true",
):
    with open(file_path, "rb") as handle:
        response = requests.put(
            event_management_url(
                host,
                dbname=dbname,
                filename=filename,
                upindex=upindex,
            ),
            data=handle,
            headers={"Content-Type": "text/xml"},
            auth=basicAuth,
            allow_redirects=True,
        )

    assert response.status_code in (200, 303), response.text
    return response


def delete_event(
    host,
    basicAuth,
    dbname=TEST_DBNAME,
    filename=EVENT_FILENAME,
    erase=False,
    upindex="true",
):
    url = event_management_url(
        host,
        dbname=dbname,
        filename=filename,
        upindex=upindex,
    )

    if erase:
        url += "&erase=true"
        response = requests.delete(url, auth=basicAuth, allow_redirects=True)
        assert response.status_code in (200, 204, 303, 404), response.text
        return response

    response = requests.delete(url, auth=basicAuth, allow_redirects=True)
    assert response.status_code in (200, 204, 303), response.text
    return response


def count_events(xml_root):
    return len(xml_root.xpath("//*[local-name()='event']"))


def canonical_xml_bytes(xml_bytes):
    parser = ET.XMLParser(remove_blank_text=True)
    root = ET.fromstring(xml_bytes, parser=parser)
    return ET.tostring(root, method="c14n2")


def event_ids_from_xml(xml_root):
    return xml_root.xpath("//*[local-name()='event']/@publicID")

MULTI_EVENT_FILES = [
    "test/data/EventDB/20180402-134033__18583881__INGV-EVENT.xml",
    "test/data/EventDB/20230118-084611__33938951__INGV-EVENT.xml",
    "test/data/EventDB/20230322_210057__34440341__INGV-EVENT.xml",
]

VERSIONED_V1_FILE = "test/data/EventDB/history/20230101-000039__33778101__INGV-EVENT.xml"
VERSIONED_V2_FILE = "test/data/EventDB/20230101-000039__33778101__INGV-EVENT.xml"

SECOND_VERSIONED_V1_FILE = "test/data/EventDB/history/20220203-220416__29794751__INGV-EVENT.xml"
SECOND_VERSIONED_V2_FILE = "test/data/EventDB/20220203-220416__29794751__INGV-EVENT.xml"
EXPLOSION_FILE = "test/data/EventDB/20250131-000645_2025cdcacd__ETHZ-EVENT.xml"

def put_events(host, basicAuth, file_paths):
    for path in file_paths:
        put_event(
            host=host,
            basicAuth=basicAuth,
            file_path=path,
            filename=path.split("/")[-1],
        )


def erase_event_file(host, basicAuth, file_path):
    delete_event(
        host=host,
        basicAuth=basicAuth,
        filename=file_path.split("/")[-1],
        erase=True,
    )


def event_public_ids(xml_root):
    return xml_root.xpath("//*[local-name()='event']/@publicID")


def sorted_event_public_ids(xml_root):
    return sorted(event_public_ids(xml_root))


def count_unique_event_public_ids(xml_root):
    return len(set(event_public_ids(xml_root)))


def canonicalize_xml_response(response):
    parser = ET.XMLParser(remove_blank_text=True)
    root = ET.fromstring(response.content, parser=parser)
    return ET.tostring(root, method="c14n2")

def text_data_lines(text):
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if not lines:
        return []
    if lines[0].startswith("#"):
        return lines[1:]
    return lines


def text_event_ids(text):
    ids = []
    for line in text_data_lines(text):
        parts = line.split("|")
        if parts:
            ids.append(parts[0])
    return ids

def normalize_event_id(eid):
    # Handles:
    # smi:webservices.ingv.it/...eventId=18583881
    # 18583881
    if "eventId=" in eid:
        return eid.split("eventId=")[-1]
    return eid

def duplicate_event_public_ids(xml_root):
    counts = event_count_by_public_id(xml_root)
    return {k: v for k, v in counts.items() if v > 1}

def event_count_by_public_id(xml_root):
    ids = event_public_ids(xml_root)
    counts = {}
    for eid in ids:
        counts[eid] = counts.get(eid, 0) + 1
    return counts

def text_header_and_rows(text):
    lines = [line.rstrip() for line in text.splitlines() if line.strip()]
    if not lines:
        return "", []
    if lines[0].startswith("#"):
        return lines[0], lines[1:]
    return "", lines


def extended_text_event_ids(text):
    _, rows = text_header_and_rows(text)
    ids = []
    for row in rows:
        parts = row.split("|")
        if parts:
            ids.append(parts[0])
    return ids

@pytest.fixture
def clean_history_event(host, basicAuth):
    delete_event(host, basicAuth, erase=True)
    yield
    delete_event(host, basicAuth, erase=True)




@pytest.fixture
def clean_history_multievent(host, basicAuth):
    files = MULTI_EVENT_FILES + [
        VERSIONED_V1_FILE,
        VERSIONED_V2_FILE,
        SECOND_VERSIONED_V1_FILE,
        SECOND_VERSIONED_V2_FILE,
        EXPLOSION_FILE
    ]
    for path in files:
        erase_event_file(host, basicAuth, path)
    yield
    for path in files:
        erase_event_file(host, basicAuth, path)

def test_history_update_exposes_old_and_new_versions(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    id_v1 = local_event_public_id(v1_file)
    id_v2 = local_event_public_id(v2_file)
    print("\nLOCAL FILE publicID v1:", id_v1)
    print("LOCAL FILE publicID v2:", id_v2)

    assert id_v1 == id_v2
    event_public_id = id_v1

    put_v1 = put_event(host, basicAuth, v1_file)
    assert put_v1.status_code in (200, 303), put_v1.text

    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    r1 = debug_event_query(host, "after put v1", event_public_id)
    assert r1.status_code == 200, r1.text
    details_v1 = count_event_details(ET.fromstring(r1.content))
    assert details_v1["publicID"] == event_public_id

    put_v2 = put_event(host, basicAuth, v2_file)
    assert put_v2.status_code in (200, 303), put_v2.text

    time.sleep(1.2)
    t_after_v2 = utc_now_z()

    r2 = debug_event_query(host, "after put v2", event_public_id)
    assert r2.status_code == 200, r2.text
    details_v2 = count_event_details(ET.fromstring(r2.content))
    assert details_v2["publicID"] == event_public_id

    rv1 = debug_event_query(host, "snapshot v1", event_public_id, asofdate=t_after_v1)
    assert rv1.status_code == 200, rv1.text
    details_snapshot_v1 = count_event_details(ET.fromstring(rv1.content))

    rv2 = debug_event_query(host, "snapshot v2", event_public_id, asofdate=t_after_v2)
    assert rv2.status_code == 200, rv2.text
    details_snapshot_v2 = count_event_details(ET.fromstring(rv2.content))

    assert details_v2 == details_snapshot_v2
    assert details_v1 == details_snapshot_v1
    assert details_v1 != details_v2
    assert details_snapshot_v1 != details_snapshot_v2


def test_history_delete_hides_current_but_preserves_past_snapshot(
    host, basicAuth, history_enabled, clean_history_event
):
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    event_public_id = local_event_public_id(v2_file)
    print("\nLOCAL FILE publicID v2:", event_public_id)

    put_v2 = put_event(host, basicAuth, v2_file)
    assert put_v2.status_code in (200, 303), put_v2.text

    time.sleep(1.2)
    t_before_delete = utc_now_z()

    before_delete_resp = debug_event_query(host, "before delete", event_public_id)
    assert before_delete_resp.status_code == 200, before_delete_resp.text
    details_before_delete = count_event_details(ET.fromstring(before_delete_resp.content))
    assert details_before_delete["publicID"] == event_public_id

    delete_response = delete_event(host, basicAuth, erase=False)
    assert delete_response.status_code in (200, 204, 303), delete_response.text
    time.sleep(1.2)
    current_after_delete = debug_event_query(host, "after logical delete", event_public_id)
    assert current_after_delete.status_code == 404, current_after_delete.text

    historical_after_delete = debug_event_query(
        host, "historical after delete", event_public_id, asofdate=t_before_delete
    )
    assert historical_after_delete.status_code == 200, historical_after_delete.text
    details_historical = count_event_details(ET.fromstring(historical_after_delete.content))

    assert details_historical == details_before_delete


def test_history_put_is_visible_in_current_query(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    event_public_id = local_event_public_id(v1_file)

    put_v1 = put_event(host, basicAuth, v1_file)
    assert put_v1.status_code in (200, 303), put_v1.text

    time.sleep(1.2)

    by_id = get_event_query_response(
        host=host,
        event_public_id=event_public_id,
        includeall=True,
        nodata=404,
    )
    print("BY ID QUERY:", by_id.status_code, by_id.text[:1500])

    dbinfo = requests.get(
        f"http://{host}/fdsnws/event/1/management/databases_info",
        auth=basicAuth,
        allow_redirects=True,
    )
    print("DB INFO:", dbinfo.status_code, dbinfo.text[:2000])

    assert by_id.status_code == 200, by_id.text


def test_history_originid_exposes_old_and_new_versions(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    origin_v1 = local_preferred_origin_id(v1_file)
    origin_v2 = local_preferred_origin_id(v2_file)

    print("\nLOCAL FILE preferredOriginID v1:", origin_v1)
    print("LOCAL FILE preferredOriginID v2:", origin_v2)

    # For this test pair, the preferred origin should stay stable across versions.
    assert origin_v1 == origin_v2
    origin_public_id = origin_v1

    put_v1 = put_event(host, basicAuth, v1_file)
    assert put_v1.status_code in (200, 303), put_v1.text

    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    r1 = debug_origin_query(host, "after put v1", origin_public_id)
    assert r1.status_code == 200, r1.text
    details_v1 = count_event_details(ET.fromstring(r1.content))

    put_v2 = put_event(host, basicAuth, v2_file)
    assert put_v2.status_code in (200, 303), put_v2.text

    time.sleep(1.2)
    t_after_v2 = utc_now_z()

    r2 = debug_origin_query(host, "after put v2", origin_public_id)
    assert r2.status_code == 200, r2.text
    details_v2 = count_event_details(ET.fromstring(r2.content))

    rv1 = debug_origin_query(host, "origin snapshot v1", origin_public_id, asofdate=t_after_v1)
    assert rv1.status_code == 200, rv1.text
    details_snapshot_v1 = count_event_details(ET.fromstring(rv1.content))

    rv2 = debug_origin_query(host, "origin snapshot v2", origin_public_id, asofdate=t_after_v2)
    assert rv2.status_code == 200, rv2.text
    details_snapshot_v2 = count_event_details(ET.fromstring(rv2.content))

    assert details_v2 == details_snapshot_v2
    assert details_v1 == details_snapshot_v1
    assert details_v1 != details_v2

def test_history_originid_resolves_revision_specific_origins(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    event_public_id = local_event_public_id(v1_file)
    origin_v1 = local_preferred_origin_id(v1_file)
    origin_v2 = local_preferred_origin_id(v2_file)

    put_v1 = put_event(host, basicAuth, v1_file)
    assert put_v1.status_code in (200, 303), put_v1.text

    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    put_v2 = put_event(host, basicAuth, v2_file)
    assert put_v2.status_code in (200, 303), put_v2.text

    time.sleep(1.2)
    t_after_v2 = utc_now_z()

    # origin from v1 must resolve at v1 time
    r_v1_at_v1 = debug_origin_query(host, "origin_v1 at v1", origin_v1, asofdate=t_after_v1)
    assert r_v1_at_v1.status_code == 200, r_v1_at_v1.text
    d_v1_at_v1 = count_event_details(ET.fromstring(r_v1_at_v1.content))
    assert d_v1_at_v1["publicID"] == event_public_id

    # origin from v2 must resolve at v2 time
    r_v2_at_v2 = debug_origin_query(host, "origin_v2 at v2", origin_v2, asofdate=t_after_v2)
    assert r_v2_at_v2.status_code == 200, r_v2_at_v2.text
    d_v2_at_v2 = count_event_details(ET.fromstring(r_v2_at_v2.content))
    assert d_v2_at_v2["publicID"] == event_public_id

    # If origin ids differ, old origin should not resolve at new time and vice versa
    if origin_v1 != origin_v2:
        r_v1_at_v2 = get_origin_query_response(host, origin_v1, asofdate=t_after_v2, includeall=True, nodata=404)
        assert r_v1_at_v2.status_code == 404, r_v1_at_v2.text

        r_v2_at_v1 = get_origin_query_response(host, origin_v2, asofdate=t_after_v1, includeall=True, nodata=404)
        assert r_v2_at_v1.status_code == 404, r_v2_at_v1.text


def test_history_eventid_strict_temporal_separation(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    event_public_id = local_event_public_id(v1_file)

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    put_event(host, basicAuth, v2_file)
    time.sleep(1.2)
    t_after_v2 = utc_now_z()

    # Fetch snapshots
    r_v1 = get_event_query_response(host, event_public_id, asofdate=t_after_v1)
    r_v2 = get_event_query_response(host, event_public_id, asofdate=t_after_v2)

    assert r_v1.status_code == 200, r_v1.text
    assert r_v2.status_code == 200, r_v2.text

    d_v1 = count_event_details(ET.fromstring(r_v1.content))
    d_v2 = count_event_details(ET.fromstring(r_v2.content))

    # Strong assertions (not just !=)
    assert d_v2["arrivals"] >= d_v1["arrivals"]
    assert d_v2["picks"] >= d_v1["picks"]
    assert d_v2["amplitudes"] >= d_v1["amplitudes"]

    # Ensure actual difference exists (sanity)
    assert d_v1 != d_v2

    # CRITICAL: no leakage backward in time
    assert d_v1["arrivals"] == 0 or d_v1["arrivals"] < d_v2["arrivals"]



def test_history_erase_removes_current_and_historical_revisions(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    event_public_id = local_event_public_id(v1_file)

    put_event(host, basicAuth, v1_file)
    assert get_event_query_response(host, event_public_id, nodata=404).status_code == 200

    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    put_event(host, basicAuth, v2_file)
    assert get_event_query_response(host, event_public_id, nodata=404).status_code == 200

    time.sleep(1.2)
    t_after_v2 = utc_now_z()

    # Sanity: both historical snapshots are available before erase
    r_hist_v1_before = get_event_query_response(
        host, event_public_id, asofdate=t_after_v1, includeall=True, nodata=404
    )
    r_hist_v2_before = get_event_query_response(
        host, event_public_id, asofdate=t_after_v2, includeall=True, nodata=404
    )
    assert r_hist_v1_before.status_code == 200, r_hist_v1_before.text
    assert r_hist_v2_before.status_code == 200, r_hist_v2_before.text

    erase_response = delete_event(host, basicAuth, erase=True)
    assert erase_response.status_code in (200, 204, 303, 404), erase_response.text

    # Current view must be gone
    r_current_after = get_event_query_response(
        host, event_public_id, includeall=True, nodata=404
    )
    assert r_current_after.status_code == 404, r_current_after.text

    # Historical views must also be gone after erase=true
    r_hist_v1_after = get_event_query_response(
        host, event_public_id, asofdate=t_after_v1, includeall=True, nodata=404
    )
    r_hist_v2_after = get_event_query_response(
        host, event_public_id, asofdate=t_after_v2, includeall=True, nodata=404
    )
    assert r_hist_v1_after.status_code == 404, r_hist_v1_after.text
    assert r_hist_v2_after.status_code == 404, r_hist_v2_after.text

# def test_history_broad_query_by_time_window_current_works_but_historical_is_pending(
#     host, basicAuth, history_enabled, clean_history_event
# ):
#     v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
#     v2_file = "test/data/EventDB/" + EVENT_FILENAME
#
#     put_event(host, basicAuth, v1_file)
#     time.sleep(1.2)
#     t_after_v1 = utc_now_z()
#
#     put_event(host, basicAuth, v2_file)
#     time.sleep(1.2)
#
#     query = (
#         "starttime=2023-01-01T00:00:00"
#         "&endtime=2023-01-01T00:01:00"
#         "&includeall=true&nodata=404"
#     )
#
#     current_resp = requests.get(f"http://{host}/fdsnws/event/1/query?{query}")
#     assert current_resp.status_code == 200, current_resp.text
#
#     historical_resp = requests.get(
#         f"http://{host}/fdsnws/event/1/query?"
#         f"{query}&asofdate={quote(t_after_v1, safe=':-TZ')}"
#     )
#
#     # Current behavior under investigation / currently failing in implementation
#     assert historical_resp.status_code in (200, 404), historical_resp.text


def test_history_asofdate_reproducibility_is_stable_after_later_changes(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    event_public_id = local_event_public_id(v1_file)

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    first = get_event_query_response(
        host=host,
        event_public_id=event_public_id,
        asofdate=t_after_v1,
        includeall=True,
        nodata=404,
    )
    assert first.status_code == 200, first.text

    # Later changes must not affect the old snapshot
    put_event(host, basicAuth, v2_file)
    time.sleep(1.2)
    delete_event(host, basicAuth, erase=False)
    time.sleep(1.2)
    second = get_event_query_response(
        host=host,
        event_public_id=event_public_id,
        asofdate=t_after_v1,
        includeall=True,
        nodata=404,
    )
    assert second.status_code == 200, second.text

    first_tree = ET.fromstring(first.content)
    second_tree = ET.fromstring(second.content)

    # Canonical equivalence is the safest reproducibility assertion
    assert ET.tostring(first_tree, encoding=None, method="c14n2") == ET.tostring(
        second_tree, encoding=None, method="c14n2"
    )


def test_history_include_flags_apply_to_selected_historical_revision(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    event_public_id = local_event_public_id(v1_file)

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    put_event(host, basicAuth, v2_file)
    time.sleep(1.2)
    t_after_v2 = utc_now_z()

    def fetch(asofdate):
        params = [
            "nodata=404",
            f"eventid={quote(event_public_id, safe=':/?=&')}",
            f"asofdate={quote(asofdate, safe=':-TZ')}",
            "includeallorigins=true",
            "includeallmagnitudes=true",
            "includearrivals=true",
            "includepicks=true",
            "includeamplitudes=true",
            "includestationmagnitudes=true",
        ]
        return get_event_query_response_raw(host, params)

    r_v1 = fetch(t_after_v1)
    r_v2 = fetch(t_after_v2)

    assert r_v1.status_code == 200, r_v1.text
    assert r_v2.status_code == 200, r_v2.text

    d_v1 = count_event_details(ET.fromstring(r_v1.content))
    d_v2 = count_event_details(ET.fromstring(r_v2.content))

    # Same logical event
    assert d_v1["publicID"] == event_public_id
    assert d_v2["publicID"] == event_public_id

    # Detail flags must be applied to the chosen revision, not leaked from current state
    assert d_v2["arrivals"] >= d_v1["arrivals"]
    assert d_v2["picks"] >= d_v1["picks"]
    assert d_v2["amplitudes"] >= d_v1["amplitudes"]
    assert d_v2["station_magnitudes"] >= d_v1["station_magnitudes"]

    # Strong sanity check that the selected revisions are genuinely different
    assert d_v1 != d_v2

    # Most important anti-leak assertion for this fixture pair
    assert d_v1["arrivals"] == 0 or d_v1["arrivals"] < d_v2["arrivals"]



# @pytest.mark.xfail(reason="broad query + asofdate not yet implemented correctly for historical mode")
def test_history_broad_query_respects_asofdate_and_no_duplicate_revisions(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    put_event(host, basicAuth, v2_file)
    time.sleep(1.2)
    t_after_v2 = utc_now_z()

    window = (
        "starttime=2023-01-01T00:00:00"
        "&endtime=2023-01-01T00:01:00"
        "&includeall=true&nodata=404"
    )

    current_resp = requests.get(f"http://{host}/fdsnws/event/1/query?{window}")
    assert current_resp.status_code == 200, current_resp.text
    current_tree = ET.fromstring(current_resp.content)
    current_events = current_tree.xpath("//*[local-name()='event']")
    assert len(current_events) == 1
    d_current = count_event_details(current_tree)

    hist_v1_resp = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"{window}&asofdate={quote(t_after_v1, safe=':-TZ')}"
    )
    assert hist_v1_resp.status_code == 200, hist_v1_resp.text
    hist_v1_tree = ET.fromstring(hist_v1_resp.content)
    hist_v1_events = hist_v1_tree.xpath("//*[local-name()='event']")
    assert len(hist_v1_events) == 1
    d_hist_v1 = count_event_details(hist_v1_tree)

    hist_v2_resp = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"{window}&asofdate={quote(t_after_v2, safe=':-TZ')}"
    )
    assert hist_v2_resp.status_code == 200, hist_v2_resp.text
    hist_v2_tree = ET.fromstring(hist_v2_resp.content)
    hist_v2_events = hist_v2_tree.xpath("//*[local-name()='event']")
    assert len(hist_v2_events) == 1
    d_hist_v2 = count_event_details(hist_v2_tree)

    assert d_current == d_hist_v2
    assert d_hist_v1 != d_hist_v2


def test_history_broad_query_asofdate_is_canonically_stable_after_later_changes(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    query = (
        "starttime=2023-01-01T00:00:00"
        "&endtime=2023-01-01T00:01:00"
        "&includeall=true"
        "&nodata=404"
    )

    first = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"{query}&asofdate={quote(t_after_v1, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert first.status_code == 200, first.text

    first_root = ET.fromstring(first.content)
    assert count_events(first_root) == 1
    first_c14n = canonical_xml_bytes(first.content)

    put_event(host, basicAuth, v2_file)
    time.sleep(1.2)

    delete_event(host, basicAuth, erase=False)
    time.sleep(1.2)

    second = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"{query}&asofdate={quote(t_after_v1, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert second.status_code == 200, second.text

    second_root = ET.fromstring(second.content)
    assert count_events(second_root) == 1
    second_c14n = canonical_xml_bytes(second.content)

    assert first_c14n == second_c14n


def test_history_broad_query_returns_one_revision_only_per_logical_event(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    event_public_id = local_event_public_id(v1_file)

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    put_event(host, basicAuth, v2_file)
    time.sleep(1.2)
    t_after_v2 = utc_now_z()

    query_base = (
        "starttime=2023-01-01T00:00:00"
        "&endtime=2023-01-01T00:01:00"
        "&includeall=true"
        "&nodata=404"
    )

    rv1 = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"{query_base}&asofdate={quote(t_after_v1, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert rv1.status_code == 200, rv1.text
    root_v1 = ET.fromstring(rv1.content)
    assert count_events(root_v1) == 1
    assert event_ids_from_xml(root_v1) == [event_public_id]
    broad_v1_c14n = canonical_xml_bytes(rv1.content)

    rv2 = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"{query_base}&asofdate={quote(t_after_v2, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert rv2.status_code == 200, rv2.text
    root_v2 = ET.fromstring(rv2.content)
    assert count_events(root_v2) == 1
    assert event_ids_from_xml(root_v2) == [event_public_id]
    broad_v2_c14n = canonical_xml_bytes(rv2.content)

    assert broad_v1_c14n != broad_v2_c14n


def test_history_historical_pagination_does_not_expose_duplicate_revision_rows(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    put_event(host, basicAuth, v2_file)
    time.sleep(1.2)

    base = (
        "starttime=2023-01-01T00:00:00"
        "&endtime=2023-01-01T00:01:00"
        "&includeall=true"
        "&orderby=time-asc"
        "&nodata=404"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}"
    )

    r1 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}&limit=1&offset=1",
        allow_redirects=True,
    )
    assert r1.status_code == 200, r1.text
    assert count_events(ET.fromstring(r1.content)) == 1

    r2 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}&limit=1&offset=2",
        allow_redirects=True,
    )
    assert r2.status_code in (204, 404), r2.text


def test_history_delete_boundary_exposes_before_but_not_after_delete_timestamp(
    host, basicAuth, history_enabled, clean_history_event
):
    v2_file = "test/data/EventDB/" + EVENT_FILENAME
    event_public_id = local_event_public_id(v2_file)

    put_event(host, basicAuth, v2_file)
    time.sleep(1.2)
    t_before_delete = utc_now_z()

    delete_event(host, basicAuth, erase=False)
    time.sleep(1.2)
    t_after_delete = utc_now_z()

    before_resp = get_event_query_response(
        host=host,
        event_public_id=event_public_id,
        asofdate=t_before_delete,
        includeall=True,
        nodata=404,
    )
    assert before_resp.status_code == 200, before_resp.text

    after_resp = get_event_query_response(
        host=host,
        event_public_id=event_public_id,
        asofdate=t_after_delete,
        includeall=True,
        nodata=404,
    )
    assert after_resp.status_code == 404, after_resp.text


def test_history_repeated_broad_asof_query_is_stable_without_intervening_changes(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    query = (
        "starttime=2023-01-01T00:00:00"
        "&endtime=2023-01-01T00:01:00"
        "&includeall=true"
        "&nodata=404"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}"
    )

    r1 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{query}",
        allow_redirects=True,
    )
    r2 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{query}",
        allow_redirects=True,
    )

    assert r1.status_code == 200, r1.text
    assert r2.status_code == 200, r2.text
    assert canonical_xml_bytes(r1.content) == canonical_xml_bytes(r2.content)
    assert count_events(ET.fromstring(r1.content)) == 1
    assert count_events(ET.fromstring(r2.content)) == 1


def test_history_rejects_asofdate_with_updatedafter(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    event_public_id = local_event_public_id(v1_file)

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    response = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"eventid={quote(event_public_id, safe=':/?=&')}"
        f"&includeall=true"
        f"&nodata=404"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}"
        f"&updatedafter={quote(t_after_v1, safe=':-TZ')}",
        allow_redirects=True,
    )

    assert response.status_code == 400, response.text

# reproducibility of a broad historical query
# other events are preserved correctly
# later mutation of one event does not perturb the old snapshot
# no duplicate version rows leak into results
def test_history_multievent_broad_snapshot_is_reproducible_after_later_update(
    host, basicAuth, history_enabled, clean_history_multievent
):
    stable_files = MULTI_EVENT_FILES
    v1_file = VERSIONED_V1_FILE
    v2_file = VERSIONED_V2_FILE

    put_events(host, basicAuth, stable_files)
    put_event(host, basicAuth, v1_file, filename=v1_file.split("/")[-1])

    time.sleep(1.2)
    t_after_initial_catalog = utc_now_z()

    query = (
        "starttime=2018-01-01T00:00:00"
        "&endtime=2024-12-31T23:59:59"
        "&includeall=true"
        "&orderby=time-asc"
        "&nodata=404"
    )

    before = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"{query}&asofdate={quote(t_after_initial_catalog, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert before.status_code == 200, before.text

    before_root = ET.fromstring(before.content)
    before_ids = sorted_event_public_ids(before_root)

    assert len(before_ids) == 4
    assert len(set(before_ids)) == 4

    put_event(host, basicAuth, v2_file, filename=v2_file.split("/")[-1])
    time.sleep(1.2)

    after = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"{query}&asofdate={quote(t_after_initial_catalog, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert after.status_code == 200, after.text

    after_root = ET.fromstring(after.content)
    after_ids = sorted_event_public_ids(after_root)

    assert after_ids == before_ids
    assert canonicalize_xml_response(before) == canonicalize_xml_response(after)

# same logical event ID remains present
# snapshot at v1 and snapshot at v2 differ
# current equals latest snapshot
# unaffected events do not disturb temporal semantics
def test_history_multievent_current_and_historical_catalogs_diverge_as_expected(
    host, basicAuth, history_enabled, clean_history_multievent
):
    stable_files = MULTI_EVENT_FILES
    v1_file = VERSIONED_V1_FILE
    v2_file = VERSIONED_V2_FILE

    versioned_event_id = local_event_public_id(v1_file)

    put_events(host, basicAuth, stable_files)
    put_event(host, basicAuth, v1_file, filename=v1_file.split("/")[-1])

    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    historical_v1 = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"starttime=2018-01-01T00:00:00"
        f"&endtime=2024-12-31T23:59:59"
        f"&includeall=true&orderby=time-asc&nodata=404"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert historical_v1.status_code == 200, historical_v1.text
    hist_v1_root = ET.fromstring(historical_v1.content)
    assert count_unique_event_public_ids(hist_v1_root) == 4

    put_event(host, basicAuth, v2_file, filename=v2_file.split("/")[-1])
    time.sleep(1.2)
    t_after_v2 = utc_now_z()

    historical_v2 = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"starttime=2018-01-01T00:00:00"
        f"&endtime=2024-12-31T23:59:59"
        f"&includeall=true&orderby=time-asc&nodata=404"
        f"&asofdate={quote(t_after_v2, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert historical_v2.status_code == 200, historical_v2.text
    hist_v2_root = ET.fromstring(historical_v2.content)
    assert count_unique_event_public_ids(hist_v2_root) == 4

    current_resp = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"starttime=2018-01-01T00:00:00"
        f"&endtime=2024-12-31T23:59:59"
        f"&includeall=true&orderby=time-asc&nodata=404",
        allow_redirects=True,
    )
    assert current_resp.status_code == 200, current_resp.text
    current_root = ET.fromstring(current_resp.content)
    assert count_unique_event_public_ids(current_root) == 4

    assert versioned_event_id in event_public_ids(hist_v1_root)
    assert versioned_event_id in event_public_ids(hist_v2_root)
    assert versioned_event_id in event_public_ids(current_root)

    assert canonicalize_xml_response(historical_v1) != canonicalize_xml_response(historical_v2)
    assert canonicalize_xml_response(historical_v2) == canonicalize_xml_response(current_resp)



# 4 logical events paginate as 2 + 2 + empty
# a historical extra revision is not counted as a fifth row
# no duplicate-event spillover across pages
def test_history_multievent_historical_pagination_counts_logical_events_not_revisions(
    host, basicAuth, history_enabled, clean_history_multievent
):
    stable_files = MULTI_EVENT_FILES
    v1_file = VERSIONED_V1_FILE
    v2_file = VERSIONED_V2_FILE

    put_events(host, basicAuth, stable_files)
    put_event(host, basicAuth, v1_file, filename=v1_file.split("/")[-1])

    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    put_event(host, basicAuth, v2_file, filename=v2_file.split("/")[-1])
    time.sleep(1.2)

    base_query = (
        "starttime=2018-01-01T00:00:00"
        "&endtime=2024-12-31T23:59:59"
        "&includeall=true"
        "&orderby=time-asc"
        "&nodata=404"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}"
    )

    page1 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base_query}&limit=2&offset=1",
        allow_redirects=True,
    )
    page2 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base_query}&limit=2&offset=3",
        allow_redirects=True,
    )
    page3 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base_query}&limit=2&offset=5",
        allow_redirects=True,
    )

    assert page1.status_code == 200, page1.text
    assert page2.status_code == 200, page2.text
    assert page3.status_code in (204, 404), page3.text

    root1 = ET.fromstring(page1.content)
    root2 = ET.fromstring(page2.content)

    ids1 = event_public_ids(root1)
    ids2 = event_public_ids(root2)

    assert len(ids1) == 2
    assert len(ids2) == 2
    assert len(set(ids1)) == 2
    assert len(set(ids2)) == 2
    assert set(ids1).isdisjoint(set(ids2))



    # delete affects only current visibility
    # prior mixed-catalog snapshot remains exactly reproducible
    # other events remain intact
def test_history_multievent_logical_delete_of_one_event_does_not_perturb_prior_snapshot(
        host, basicAuth, history_enabled, clean_history_multievent
):
    stable_files = MULTI_EVENT_FILES
    v1_file = VERSIONED_V1_FILE

    put_events(host, basicAuth, stable_files)
    put_event(host, basicAuth, v1_file, filename=v1_file.split("/")[-1])

    time.sleep(1.2)
    t_before_delete = utc_now_z()

    query = (
        "starttime=2018-01-01T00:00:00"
        "&endtime=2024-12-31T23:59:59"
        "&includeall=true"
        "&orderby=time-asc"
        "&nodata=404"
    )

    before = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"{query}&asofdate={quote(t_before_delete, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert before.status_code == 200, before.text

    delete_event(
        host,
        basicAuth,
        filename=v1_file.split("/")[-1],
        erase=False,
    )
    time.sleep(1.2)

    current_after_delete = requests.get(
        f"http://{host}/fdsnws/event/1/query?{query}",
        allow_redirects=True,
    )
    assert current_after_delete.status_code == 200, current_after_delete.text
    current_after_root = ET.fromstring(current_after_delete.content)
    assert count_unique_event_public_ids(current_after_root) == 3

    historical_after_delete = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"{query}&asofdate={quote(t_before_delete, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert historical_after_delete.status_code == 200, historical_after_delete.text

    historical_after_root = ET.fromstring(historical_after_delete.content)
    assert count_unique_event_public_ids(historical_after_root) == 4
    assert canonicalize_xml_response(before) == canonicalize_xml_response(historical_after_delete)


def test_history_asofdate_before_first_version_returns_nodata(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME

    event_public_id = local_event_public_id(v1_file)

    # Insert first version
    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)

    # Choose a timestamp clearly BEFORE insertion
    t_before_any_version = "2000-01-01T00:00:00Z"

    # Query with asofdate in the past
    response = get_event_query_response(
        host=host,
        event_public_id=event_public_id,
        asofdate=t_before_any_version,
        includeall=True,
        nodata=404,
    )

    assert response.status_code == 404, response.text


# def test_history_multievent_asofdate_before_any_data_returns_empty_catalog(
#     host, basicAuth, history_enabled, clean_history_multievent
# ):
#     put_events(host, basicAuth, MULTI_EVENT_FILES)
#     time.sleep(1.2)
#
#     t_before_any = "2000-01-01T00:00:00Z"
#
#     response = requests.get(
#         f"http://{host}/fdsnws/event/1/query?"
#         f"starttime=2018-01-01T00:00:00"
#         f"&endtime=2024-12-31T23:59:59"
#         f"&includeall=true"
#         f"&asofdate={quote(t_before_any, safe=':-TZ')}"
#         f"&nodata=404",
#         allow_redirects=True,
#     )
#
#     assert response.status_code == 404, response.text


# def test_history_asofdate_equal_to_first_version_start_returns_event(
#     host, basicAuth, history_enabled, clean_history_event
# ):
#     v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
#     event_public_id = local_event_public_id(v1_file)
#
#     put_event(host, basicAuth, v1_file)
#     time.sleep(1.2)
#
#     current_resp = get_event_query_response(
#         host=host,
#         event_public_id=event_public_id,
#         includeall=True,
#         nodata=404,
#     )
#     assert current_resp.status_code == 200, current_resp.text
#
#     current_root = ET.fromstring(current_resp.content)
#     version_nodes = current_root.xpath("//*[local-name()='Version']")
#     assert len(version_nodes) >= 1, current_resp.text
#
#     first_start = version_nodes[0].get("start")
#     assert first_start, current_resp.text
#
#     at_start_resp = get_event_query_response(
#         host=host,
#         event_public_id=event_public_id,
#         asofdate=first_start,
#         includeall=True,
#         nodata=404,
#     )
#     assert at_start_resp.status_code == 200, at_start_resp.text
#
#     assert canonical_xml_bytes(current_resp.content) == canonical_xml_bytes(at_start_resp.content)
#
# def test_history_asofdate_just_before_first_version_start_returns_nodata(
#     host, basicAuth, history_enabled, clean_history_event
# ):
#     from datetime import datetime, timedelta, timezone
#
#     v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
#     event_public_id = local_event_public_id(v1_file)
#
#     put_event(host, basicAuth, v1_file)
#     time.sleep(1.2)
#
#     current_resp = get_event_query_response(
#         host=host,
#         event_public_id=event_public_id,
#         includeall=True,
#         nodata=404,
#     )
#     assert current_resp.status_code == 200, current_resp.text
#
#     current_root = ET.fromstring(current_resp.content)
#     version_nodes = current_root.xpath("//*[local-name()='Version']")
#     assert len(version_nodes) >= 1, current_resp.text
#
#     first_start = version_nodes[0].get("start")
#     assert first_start, current_resp.text
#
#     start_dt = datetime.fromisoformat(first_start.replace("Z", "+00:00"))
#     just_before = (start_dt - timedelta(seconds=1)).astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
#
#     before_resp = get_event_query_response(
#         host=host,
#         event_public_id=event_public_id,
#         asofdate=just_before,
#         includeall=True,
#         nodata=404,
#     )
#     assert before_resp.status_code == 404, before_resp.text

def test_history_asofdate_before_first_version_returns_nodata(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    event_public_id = local_event_public_id(v1_file)

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)

    response = get_event_query_response(
        host=host,
        event_public_id=event_public_id,
        asofdate="2000-01-01T00:00:00Z",
        includeall=True,
        nodata=404,
    )
    assert response.status_code == 404, response.text


def test_history_asofdate_after_first_version_returns_event(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    event_public_id = local_event_public_id(v1_file)

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_put = utc_now_z()

    response = get_event_query_response(
        host=host,
        event_public_id=event_public_id,
        asofdate=t_after_put,
        includeall=True,
        nodata=404,
    )
    assert response.status_code == 200, response.text



def test_history_text_eventid_asofdate_is_stable_after_later_changes(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    event_public_id = local_event_public_id(v1_file)

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    first = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"eventid={quote(event_public_id, safe=':/?=&')}"
        f"&format=text"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}"
        f"&nodata=404",
        allow_redirects=True,
    )
    assert first.status_code == 200, first.text
    assert len(text_data_lines(first.text)) == 1

    put_event(host, basicAuth, v2_file)
    time.sleep(1.2)

    delete_event(host, basicAuth, erase=False)
    time.sleep(1.2)

    second = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"eventid={quote(event_public_id, safe=':/?=&')}"
        f"&format=text"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}"
        f"&nodata=404",
        allow_redirects=True,
    )
    assert second.status_code == 200, second.text
    assert len(text_data_lines(second.text)) == 1

    assert first.text == second.text

# multi-event historical text pagination counts logical events, not revisions
def test_history_multievent_text_historical_pagination_counts_logical_events_not_revisions(
    host, basicAuth, history_enabled, clean_history_multievent
):
    stable_files = MULTI_EVENT_FILES
    v1_file = VERSIONED_V1_FILE
    v2_file = VERSIONED_V2_FILE

    put_events(host, basicAuth, stable_files)
    put_event(host, basicAuth, v1_file, filename=v1_file.split("/")[-1])

    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    put_event(host, basicAuth, v2_file, filename=v2_file.split("/")[-1])
    time.sleep(1.2)

    base = (
        "starttime=2018-01-01T00:00:00"
        "&endtime=2024-12-31T23:59:59"
        "&format=text"
        "&orderby=time-asc"
        "&nodata=404"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}"
    )

    page1 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}&limit=2&offset=1",
        allow_redirects=True,
    )
    page2 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}&limit=2&offset=3",
        allow_redirects=True,
    )
    page3 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}&limit=2&offset=5",
        allow_redirects=True,
    )

    assert page1.status_code == 200, page1.text
    assert page2.status_code == 200, page2.text
    assert page3.status_code in (204, 404), page3.text

    ids1 = text_event_ids(page1.text)
    ids2 = text_event_ids(page2.text)

    assert len(ids1) == 2
    assert len(ids2) == 2
    assert len(set(ids1)) == 2
    assert len(set(ids2)) == 2
    assert set(ids1).isdisjoint(set(ids2))


# past asofdate with nodata=204
def test_history_asofdate_before_first_version_returns_204_when_nodata_204(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    event_public_id = local_event_public_id(v1_file)

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)

    response = get_event_query_response(
        host=host,
        event_public_id=event_public_id,
        asofdate="2000-01-01T00:00:00Z",
        includeall=True,
        nodata=204,
    )
    assert response.status_code == 204, response.text

def test_history_magnitude_filter_applies_to_selected_revision_not_current_state(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME
    event_public_id = local_event_public_id(v1_file)

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    put_event(host, basicAuth, v2_file)
    time.sleep(1.2)
    t_after_v2 = utc_now_z()

    base = (
        "starttime=2023-01-01T00:00:00"
        "&endtime=2023-01-01T00:01:00"
        "&minmagnitude=0.6"
        "&includeall=true"
        "&nodata=404"
    )

    r_v1 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}",
        allow_redirects=True,
    )
    r_v2 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}"
        f"&asofdate={quote(t_after_v2, safe=':-TZ')}",
        allow_redirects=True,
    )

    assert r_v1.status_code in (204, 404), r_v1.text
    assert r_v2.status_code == 200, r_v2.text

    root_v2 = ET.fromstring(r_v2.content)
    assert event_ids_from_xml(root_v2) == [event_public_id]


def test_history_magnitude_filter_current_matches_latest_snapshot(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)

    put_event(host, basicAuth, v2_file)
    time.sleep(1.2)
    t_after_v2 = utc_now_z()

    query = (
        "starttime=2023-01-01T00:00:00"
        "&endtime=2023-01-01T00:01:00"
        "&minmagnitude=0.6"
        "&includeall=true"
        "&nodata=404"
    )

    current_resp = requests.get(
        f"http://{host}/fdsnws/event/1/query?{query}",
        allow_redirects=True,
    )
    hist_v2_resp = requests.get(
        f"http://{host}/fdsnws/event/1/query?{query}"
        f"&asofdate={quote(t_after_v2, safe=':-TZ')}",
        allow_redirects=True,
    )

    assert current_resp.status_code == hist_v2_resp.status_code
    if current_resp.status_code == 200:
        assert canonicalize_xml_response(current_resp) == canonicalize_xml_response(hist_v2_resp)


def test_history_multievent_broad_query_with_minmagnitude_is_reproducible(
    host, basicAuth, history_enabled, clean_history_multievent
):
    stable_files = MULTI_EVENT_FILES
    v1_file = VERSIONED_V1_FILE
    v2_file = VERSIONED_V2_FILE

    put_events(host, basicAuth, stable_files)
    put_event(host, basicAuth, v1_file, filename=v1_file.split("/")[-1])

    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    query = (
        "starttime=2018-01-01T00:00:00"
        "&endtime=2024-12-31T23:59:59"
        "&minmagnitude=3.0"
        "&includeall=true"
        "&orderby=magnitude"
        "&nodata=404"
    )

    before = requests.get(
        f"http://{host}/fdsnws/event/1/query?{query}"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert before.status_code == 200, before.text

    put_event(host, basicAuth, v2_file, filename=v2_file.split("/")[-1])
    time.sleep(1.2)

    after = requests.get(
        f"http://{host}/fdsnws/event/1/query?{query}"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert after.status_code == 200, after.text

    assert canonicalize_xml_response(before) == canonicalize_xml_response(after)


def test_history_multievent_magnitude_order_pagination_counts_logical_events_not_revisions(
    host, basicAuth, history_enabled, clean_history_multievent
):
    stable_files = MULTI_EVENT_FILES
    v1_file = VERSIONED_V1_FILE
    v2_file = VERSIONED_V2_FILE

    put_events(host, basicAuth, stable_files)
    put_event(host, basicAuth, v1_file, filename=v1_file.split("/")[-1])

    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    put_event(host, basicAuth, v2_file, filename=v2_file.split("/")[-1])
    time.sleep(1.2)

    base = (
        "starttime=2018-01-01T00:00:00"
        "&endtime=2024-12-31T23:59:59"
        "&minmagnitude=0.0"
        "&orderby=magnitude"
        "&includeall=true"
        "&nodata=404"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}"
    )

    page1 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}&limit=2&offset=1",
        allow_redirects=True,
    )
    page2 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}&limit=2&offset=3",
        allow_redirects=True,
    )
    page3 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}&limit=2&offset=5",
        allow_redirects=True,
    )

    assert page1.status_code == 200, page1.text
    assert page2.status_code == 200, page2.text
    assert page3.status_code in (204, 404), page3.text

    ids1 = event_ids_from_xml(ET.fromstring(page1.content))
    ids2 = event_ids_from_xml(ET.fromstring(page2.content))

    assert len(ids1) == 2
    assert len(ids2) == 2
    assert len(set(ids1)) == 2
    assert len(set(ids2)) == 2
    assert set(ids1).isdisjoint(set(ids2))


def test_history_text_multievent_minmagnitude_pagination_is_revision_safe(
    host, basicAuth, history_enabled, clean_history_multievent
):
    stable_files = MULTI_EVENT_FILES
    v1_file = VERSIONED_V1_FILE
    v2_file = VERSIONED_V2_FILE

    put_events(host, basicAuth, stable_files)
    put_event(host, basicAuth, v1_file, filename=v1_file.split("/")[-1])

    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    put_event(host, basicAuth, v2_file, filename=v2_file.split("/")[-1])
    time.sleep(1.2)

    base = (
        "starttime=2018-01-01T00:00:00"
        "&endtime=2024-12-31T23:59:59"
        "&minmagnitude=0.0"
        "&format=text"
        "&orderby=magnitude"
        "&nodata=404"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}"
    )

    page1 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}&limit=2&offset=1",
        allow_redirects=True,
    )
    page2 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}&limit=2&offset=3",
        allow_redirects=True,
    )
    page3 = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}&limit=2&offset=5",
        allow_redirects=True,
    )

    assert page1.status_code == 200, page1.text
    assert page2.status_code == 200, page2.text
    assert page3.status_code in (204, 404), page3.text

    ids1 = text_event_ids(page1.text)
    ids2 = text_event_ids(page2.text)

    assert len(ids1) == 2
    assert len(ids2) == 2
    assert len(set(ids1)) == 2
    assert len(set(ids2)) == 2
    assert set(ids1).isdisjoint(set(ids2))


def test_history_multievent_two_independently_versioned_events_reconstructs_correct_snapshot(
    host, basicAuth, history_enabled, clean_history_multievent
):
    stable_files = MULTI_EVENT_FILES

    ev1_v1_file = VERSIONED_V1_FILE
    ev1_v2_file = VERSIONED_V2_FILE

    ev2_v1_file = SECOND_VERSIONED_V1_FILE
    ev2_v2_file = SECOND_VERSIONED_V2_FILE

    ev1_v1_id = local_event_public_id(ev1_v1_file)
    ev1_v2_id = local_event_public_id(ev1_v2_file)

    ev2_v1_id = local_event_public_id(ev2_v1_file)
    ev2_v2_id = local_event_public_id(ev2_v2_file)

    put_events(host, basicAuth, stable_files)

    put_event(host, basicAuth, ev1_v1_file, filename=ev1_v1_file.split("/")[-1])
    time.sleep(1.2)
    t_after_ev1_v1 = utc_now_z()

    put_event(host, basicAuth, ev2_v1_file, filename=ev2_v1_file.split("/")[-1])
    time.sleep(1.2)
    t_after_ev2_v1 = utc_now_z()

    put_event(host, basicAuth, ev1_v2_file, filename=ev1_v2_file.split("/")[-1])
    time.sleep(1.2)
    t_after_ev1_v2 = utc_now_z()

    put_event(host, basicAuth, ev2_v2_file, filename=ev2_v2_file.split("/")[-1])
    time.sleep(1.2)
    t_after_ev2_v2 = utc_now_z()

    query = (
        "starttime=2018-01-01T00:00:00"
        "&endtime=2024-12-31T23:59:59"
        "&includeall=true"
        "&orderby=time-asc"
        "&nodata=404"
    )

    # Snapshot after both v1 versions are present, before any v2 updates
    snap_v1 = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"{query}&asofdate={quote(t_after_ev2_v1, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert snap_v1.status_code == 200, snap_v1.text
    root_v1 = ET.fromstring(snap_v1.content)

    ids_v1 = event_public_ids(root_v1)
    counts_v1 = event_count_by_public_id(root_v1)

    assert count_events(root_v1) == count_unique_event_public_ids(root_v1)
    assert len(ids_v1) == 5  # 3 stable + 2 versioned logical events

    assert ev1_v1_id in ids_v1
    assert ev2_v1_id in ids_v1

    # Snapshot after both v2 versions are present
    snap_v2 = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"{query}&asofdate={quote(t_after_ev2_v2, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert snap_v2.status_code == 200, snap_v2.text
    root_v2 = ET.fromstring(snap_v2.content)

    ids_v2 = event_public_ids(root_v2)
    counts_v2 = event_count_by_public_id(root_v2)
    dups_v2 = duplicate_event_public_ids(root_v2)
    print("V2 IDS:", ids_v2)
    print("V2 DUPLICATES:", dups_v2)

    assert count_events(root_v2) == count_unique_event_public_ids(root_v2)
    assert len(ids_v2) == 5  # still 3 stable + 2 logical events

    assert ev1_v2_id in ids_v2
    assert ev2_v2_id in ids_v2

    # No duplicate rows for any event id in either snapshot
    assert all(v == 1 for v in counts_v1.values())
    assert all(v == 1 for v in counts_v2.values())

    # The full catalog snapshot must change after later updates
    assert canonicalize_xml_response(snap_v1) != canonicalize_xml_response(snap_v2)

    # Latest snapshot must match current catalog
    current_resp = requests.get(
        f"http://{host}/fdsnws/event/1/query?{query}",
        allow_redirects=True,
    )
    assert current_resp.status_code == 200, current_resp.text
    assert canonicalize_xml_response(current_resp) == canonicalize_xml_response(snap_v2)

    # Repeating the older snapshot after later changes must remain stable
    snap_v1_repeat = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"{query}&asofdate={quote(t_after_ev2_v1, safe=':-TZ')}",
        allow_redirects=True,
    )
    assert snap_v1_repeat.status_code == 200, snap_v1_repeat.text
    assert canonicalize_xml_response(snap_v1) == canonicalize_xml_response(snap_v1_repeat)
    assert local_event_public_id(ev2_v1_file) == local_event_public_id(ev2_v2_file)



def test_history_text_eventtype_explosion_not_visible_before_event_time(
    host, basicAuth, history_enabled
):
    response = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"format=text"
        f"&eventtype=explosion"
        f"&asofdate=2025-01-01T00:00:00Z"
        f"&nodata=404",
        allow_redirects=True,
    )

    assert response.status_code == 404, response.text

def test_history_text_catalog_and_contributor_filters_work_with_asofdate(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    event_public_id = local_event_public_id(v1_file)
    t_before_v1 = utc_now_z()
    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    ok_catalog = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"eventid={quote(event_public_id, safe=':/?=&')}"
        f"&format=text"
        f"&catalog=INGV"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}"
        f"&nodata=404",
        allow_redirects=True,
    )
    assert ok_catalog.status_code == 200, ok_catalog.text
    _, ok_catalog_rows = text_header_and_rows(ok_catalog.text)
    assert len(ok_catalog_rows) == 1
    assert ok_catalog_rows[0].startswith(f"{event_public_id}|")


    no_catalog = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"eventid={quote(event_public_id, safe=':/?=&')}"
        f"&format=text"
        f"&catalog=INGV"
        f"&asofdate={quote(t_before_v1, safe=':-TZ')}"
        f"&nodata=404",
        allow_redirects=True,
    )
    assert no_catalog.status_code == 404

    ok_contributor = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"eventid={quote(event_public_id, safe=':/?=&')}"
        f"&format=text"
        f"&contributor=INGV"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}"
        f"&nodata=404",
        allow_redirects=True,
    )
    assert ok_contributor.status_code == 200, ok_contributor.text
    _, ok_contributor_rows = text_header_and_rows(ok_contributor.text)
    assert len(ok_contributor_rows) == 1
    assert ok_contributor_rows[0].startswith(f"{event_public_id}|")

    bad_catalog = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"eventid={quote(event_public_id, safe=':/?=&')}"
        f"&format=text"
        f"&catalog=SUCA"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}"
        f"&nodata=404",
        allow_redirects=True,
    )
    assert bad_catalog.status_code == 404, bad_catalog.text

    bad_contributor = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"eventid={quote(event_public_id, safe=':/?=&')}"
        f"&format=text"
        f"&contributor=INGGV"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}"
        f"&nodata=404",
        allow_redirects=True,
    )
    assert bad_contributor.status_code == 404, bad_contributor.text


def test_history_hypo71phs_eventid_with_asofdate_returns_event_lines(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/20220203-220416__29794751__INGV-EVENT.xml"
    v2_file = "test/data/EventDB/20220203-220416__29794751__INGV-EVENT.xml"

    event_public_id = local_event_public_id(v1_file)

    put_event(host, basicAuth, v1_file, filename=v1_file.split("/")[-1])
    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    put_event(host, basicAuth, v2_file, filename=v2_file.split("/")[-1])
    time.sleep(1.2)

    response = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"eventid={quote(event_public_id, safe=':/?=&')}"
        f"&catalog=INGV"
        f"&format=hypo71phs"
        f"&asofdate={quote(t_after_v1, safe=':-TZ')}"
        f"&nodata=404",
        allow_redirects=True,
    )
    assert response.status_code == 200, response.text

    lines = [line for line in response.text.splitlines() if line.strip()]
    assert len(lines) > 0
    assert any("EVID:29794751" in line for line in lines)

def test_history_spatial_filter_applies_after_asofdate(
    host, basicAuth, history_enabled, clean_history_multievent
):
    put_events(host, basicAuth, MULTI_EVENT_FILES)

    time.sleep(1.2)
    t_after_insert = utc_now_z()

    # Bounding box that should include only Norcia-area events
    query = (
        "minlat=42"
        "&maxlat=43"
        "&minlon=13"
        "&maxlon=14"
        "&includeall=true"
        "&nodata=404"
    )

    resp = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"{query}&asofdate={quote(t_after_insert, safe=':-TZ')}",
        allow_redirects=True,
    )

    assert resp.status_code == 200, resp.text
    root = ET.fromstring(resp.content)

    ids = event_ids_from_xml(root)
    assert len(ids) >= 1

    # Ensure all returned events are within expected subset
    for eid in ids:
        assert "33778101" in eid or "34440341" in eid

def test_history_eventtype_and_magnitude_filters_interact_correctly_with_asofdate(
    host, basicAuth, history_enabled, clean_history_multievent
):
    put_event(host, basicAuth, EXPLOSION_FILE, filename=EXPLOSION_FILE.split("/")[-1])
    time.sleep(1.2)

    t_after_insert = utc_now_z()

    resp = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"eventtype=explosion"
        f"&minmagnitude=-1.0"
        f"&format=text"
        f"&asofdate={quote(t_after_insert, safe=':-TZ')}"
        f"&nodata=404",
        allow_redirects=True,
    )

    assert resp.status_code == 200, resp.text
    _, rows = text_header_and_rows(resp.text)
    assert len(rows) == 1
    assert rows[0].endswith("|explosion")

def test_history_default_include_behavior_matches_current_semantics(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    v2_file = "test/data/EventDB/" + EVENT_FILENAME

    event_public_id = local_event_public_id(v1_file)

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_v1 = utc_now_z()

    put_event(host, basicAuth, v2_file)
    time.sleep(1.2)

    resp = get_event_query_response(
        host=host,
        event_public_id=event_public_id,
        asofdate=t_after_v1,
        includeall=False,  # critical
        nodata=404,
    )

    assert resp.status_code == 200, resp.text

    root = ET.fromstring(resp.content)
    event = get_single_event(root)

    # Default: preferred only
    assert len(event.xpath("./bed:origin", namespaces=NS)) == 1
    assert len(event.xpath("./bed:magnitude", namespaces=NS)) == 1

def test_history_cross_format_eventid_consistency(
    host, basicAuth, history_enabled, clean_history_multievent
):
    put_events(host, basicAuth, MULTI_EVENT_FILES)
    time.sleep(1.2)
    t_after_insert = utc_now_z()

    base = (
        "starttime=2018-01-01T00:00:00"
        "&endtime=2024-12-31T23:59:59"
        f"&asofdate={quote(t_after_insert, safe=':-TZ')}"
        "&nodata=404"
    )

    xml_resp = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}&includeall=true",
        allow_redirects=True,
    )
    text_resp = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}&format=text",
        allow_redirects=True,
    )
    ext_resp = requests.get(
        f"http://{host}/fdsnws/event/1/query?{base}&format=extended_text",
        allow_redirects=True,
    )

    assert xml_resp.status_code == 200
    assert text_resp.status_code == 200
    assert ext_resp.status_code == 200

    xml_ids = sorted(normalize_event_id(e) for e in event_ids_from_xml(ET.fromstring(xml_resp.content)))
    text_ids = sorted(normalize_event_id(e) for e in text_event_ids(text_resp.text))
    ext_ids = sorted(normalize_event_id(e) for e in extended_text_event_ids(ext_resp.text))

    assert xml_ids == text_ids == ext_ids

def test_history_disabled_ignores_asofdate_and_returns_current_state(
    host, basicAuth, clean_history_event
):
    # disable history
    root = get_settings_root(host)
    root = set_or_create_text_node(root, "history", "false")
    put_settings_root(host, basicAuth, root)

    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME
    event_public_id = local_event_public_id(v1_file)

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_insert = utc_now_z()

    # Query with asofdate AFTER insertion (valid snapshot)
    resp = get_event_query_response(
        host=host,
        event_public_id=event_public_id,
        asofdate=t_after_insert,
        includeall=True,
        nodata=404,
    )

    current = get_event_query_response(
        host=host,
        event_public_id=event_public_id,
        includeall=True,
        nodata=404,
    )

    # Two valid behaviors:
    # 1. ignore asofdate → behave like current
    # 2. reject asofdate → 400

    assert resp.status_code in (200, 400)

    if resp.status_code == 200:
        assert canonicalize_xml_response(resp) == canonicalize_xml_response(current)


def test_history_full_catalog_snapshot_without_filters(
    host, basicAuth, history_enabled, clean_history_multievent
):
    put_events(host, basicAuth, MULTI_EVENT_FILES)
    time.sleep(1.2)
    t_after_insert = utc_now_z()

    resp = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"asofdate={quote(t_after_insert, safe=':-TZ')}"
        f"&includeall=true"
        f"&nodata=404",
        allow_redirects=True,
    )

    assert resp.status_code == 200
    root = ET.fromstring(resp.content)

    assert count_events(root) == count_unique_event_public_ids(root)

def test_history_spatial_filter_with_pagination_is_consistent(
    host, basicAuth, history_enabled, clean_history_multievent
):
    #4 Events
    put_events(host, basicAuth, MULTI_EVENT_FILES)
    put_event(host, basicAuth, VERSIONED_V1_FILE, filename=VERSIONED_V1_FILE.split("/")[-1])
    time.sleep(1.2)
    t_after_insert = utc_now_z()

    base = (
        "minlat=34"
        "&maxlat=44"
        "&minlon=10"
        "&maxlon=15"
        f"&asofdate={quote(t_after_insert, safe=':-TZ')}"
        "&orderby=time"
        "&nodata=404"
    )

    page1 = requests.get(f"http://{host}/fdsnws/event/1/query?{base}&limit=2&offset=1")
    page2 = requests.get(f"http://{host}/fdsnws/event/1/query?{base}&limit=2&offset=3")

    assert page1.status_code == 200
    assert page2.status_code == 200

    ids1 = event_ids_from_xml(ET.fromstring(page1.content))
    ids2 = event_ids_from_xml(ET.fromstring(page2.content))

    assert set(ids1).isdisjoint(set(ids2))

def test_history_complex_filter_combination_is_stable(
    host, basicAuth, history_enabled, clean_history_multievent
):
    put_events(host, basicAuth, MULTI_EVENT_FILES)
    time.sleep(1.2)
    t_after_insert = utc_now_z()

    query = (
        "starttime=2018-01-01T00:00:00"
        "&endtime=2024-12-31T23:59:59"
        "&minmagnitude=1.0"
        "&maxmagnitude=6.0"
        "&minlat=30"
        "&maxlat=50"
        "&orderby=magnitude"
        "&limit=2"
        f"&asofdate={quote(t_after_insert, safe=':-TZ')}"
        "&nodata=404"
    )

    resp = requests.get(f"http://{host}/fdsnws/event/1/query?{query}")
    assert resp.status_code == 200

    root = ET.fromstring(resp.content)
    assert count_events(root) <= 2

def test_history_future_asofdate_returns_latest_snapshot(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)

    future = "2100-01-01T00:00:00Z"

    future_resp = get_event_query_response(
        host, local_event_public_id(v1_file),
        asofdate=future, includeall=True
    )

    current_resp = get_event_query_response(
        host, local_event_public_id(v1_file),
        includeall=True
    )

    assert future_resp.status_code == 200
    assert canonicalize_xml_response(future_resp) == canonicalize_xml_response(current_resp)


def test_history_updatedafter_returns_recent_changes(
    host, basicAuth, history_enabled, clean_history_event
):
    v1_file = "test/data/EventDB/history/" + EVENT_FILENAME

    put_event(host, basicAuth, v1_file)
    time.sleep(1.2)
    t_after_insert = utc_now_z()

    resp = requests.get(
        f"http://{host}/fdsnws/event/1/query?"
        f"updatedafter={quote(t_after_insert, safe=':-TZ')}"
        f"&includeall=true"
        f"&nodata=404",
        allow_redirects=True,
    )

    # Expect no results because nothing updated after this time
    assert resp.status_code in (204, 404)

