import os

import pytest

import poller

NOW = 1_800_000_000.0   # a fixed "time of the run"
MIN, HOUR = 60, 3600


@pytest.fixture
def scans(tmp_path, monkeypatch):
    """Point poller at an empty fake scan folder; returns make(rel, mtime, study_mtime=None)."""
    root = tmp_path / "scan_data"
    root.mkdir()
    monkeypatch.setattr(poller, "WATCHDIR", str(root) + "/")
    monkeypatch.setattr(poller, "STATE_FILE", str(tmp_path / "var" / "state.json"))
    monkeypatch.setattr(poller, "LOCK_FILE", str(tmp_path / "lock"))

    def make(rel, mtime, study_mtime=None):
        """Create <study>/.../<series>/MR.1 with every folder stamped `mtime`
        (the top-level study folder gets `study_mtime` if given)."""
        series = root / rel
        series.mkdir(parents=True)
        (series / "MR.1").write_text("x")
        parts = rel.split("/")
        for i in range(len(parts), 0, -1):
            os.utime(root.joinpath(*parts[:i]), (mtime, mtime))
        if study_mtime is not None:
            os.utime(root / parts[0], (study_mtime, study_mtime))
        return str(series)
    return make


def fresh_state():
    return {"cutoff": None, "retry": {}, "done": {}}


def test_finds_only_series_that_settled_in_the_window(scans):
    """First run looks back 2h: a 1h-old series is found, a 3h-old one is not,
    and a 2-minute-old one is still 'settling' (left for the next run)."""
    inside = scans("S/a/subj/ep.1", NOW - 1 * HOUR)
    scans("S/b/subj/ep.1", NOW - 3 * HOUR)
    scans("S/c/subj/ep.1", NOW - 2 * MIN)
    found, counts, new_cutoff = poller.find_new(fresh_state(), NOW)
    assert list(found) == [inside]
    assert found[inside].endswith("MR.1")
    assert counts["settling"] == 1
    assert new_cutoff == NOW - poller.SETTLE_SECONDS


def test_each_series_is_found_exactly_once(scans):
    """The next run starts where this one stopped: a series stamped exactly on the
    cutoff is skipped by run 1 and picked up by run 2, and run 1's series is not repeated."""
    first = scans("S/a/subj/ep.1", NOW - 1 * HOUR)
    on_cutoff = scans("S/b/subj/ep.1", NOW - poller.SETTLE_SECONDS)
    state = fresh_state()

    found, _, cutoff = poller.find_new(state, NOW)
    assert list(found) == [first]            # the one on the cutoff is 'settling'
    state["cutoff"] = cutoff

    found, _, _ = poller.find_new(state, NOW + 10 * MIN)
    assert list(found) == [on_cutoff]        # picked up now, and `first` is not repeated


def test_cron_outage_only_looks_back_24h(scans):
    """A saved cutoff from 3 days ago is clamped to MAX_LOOKBACK."""
    scans("S/old/subj/ep.1", NOW - 30 * HOUR)
    recent = scans("S/recent/subj/ep.1", NOW - 20 * HOUR)
    state = {"cutoff": NOW - 72 * HOUR, "retry": {}, "done": {}}
    found, _, _ = poller.find_new(state, NOW)
    assert list(found) == [recent]


def test_stale_study_folders_are_skipped_but_homeless_is_always_walked(scans):
    """A study folder untouched for 30 days is skipped without looking inside.
    'homeless' is the exception: its own mtime says nothing about new sessions."""
    stamp = NOW - 1 * HOUR
    scans("OLDSTUDY/s/subj/ep.1", stamp, study_mtime=NOW - 30 * 24 * HOUR)
    homeless = scans("homeless/Brain^Prisma1QC/s/PRISMA1QA/ep.1", stamp, study_mtime=NOW - 30 * 24 * HOUR)
    found, counts, _ = poller.find_new(fresh_state(), NOW)
    assert list(found) == [homeless]
    assert counts["studies"] == 1


def test_state_round_trip_and_corrupt_state_stops(scans):
    """save_state/load_state keep the cutoff, retries and done list; a garbled file stops the run."""
    state = {"cutoff": 123.5, "retry": {"/a/b": 2}, "done": {"rule|S/a": 99.0}}
    poller.save_state(state)
    assert poller.load_state() == state

    with open(poller.STATE_FILE, "w") as f:
        f.write("{not json")
    with pytest.raises(SystemExit) as e:
        poller.load_state()
    assert e.value.code == 1


def test_second_run_exits_quietly_while_first_is_running(scans):
    """A second acquire_lock() while the first is held exits with code 0."""
    held = poller.acquire_lock()
    try:
        with pytest.raises(SystemExit) as e:
            poller.acquire_lock()
        assert e.value.code == 0
    finally:
        held.close()
