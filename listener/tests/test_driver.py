"""Tests for driver.py.  Run from listener/: python -m pytest tests/test_driver.py"""
import driver
import time

SCAN = driver.poller.WATCHDIR
P3_LOCALIZER = SCAN + "PRISMA3QC/2026.11.11-06.27.15/PRISMA3QA20261111/localizer_256x256.1"
P1_BOLD = SCAN + "homeless/Brain^Prisma1QC/2026.11.12-06.20.29/PRISMA1QA20261112/ep2d_bold_p2_s2_5min_658x658.3"
HUMAN = SCAN + "WPC-9628/2026.11.11-14.58.06/RADIANT_018/MPRAGE_320x300.2"
OTHER_HOMELESS = SCAN + "homeless/7TBRP^RFLAB/2026.11.08-08.24.12/26-08-11_G2plus-phantom/localizer_5_512x512.1"


def test_is_phantom():
    assert driver.is_phantom(P3_LOCALIZER)
    assert driver.is_phantom(P1_BOLD)
    assert not driver.is_phantom(HUMAN)
    assert not driver.is_phantom(OTHER_HOMELESS)


def test_every_scanner_is_recognised():
    for n in ["1", "2", "3"]:
        assert driver.is_phantom(SCAN + "PRISMA" + n + "QC/2026.11.11-06.27.15/X/localizer.1")
        assert driver.is_phantom(SCAN + "homeless/Brain^Prisma" + n + "QC/2026.11.11-06.27.15/X/localizer.1")


def test_is_bold():
    assert driver.is_bold(P1_BOLD)
    assert not driver.is_bold(P3_LOCALIZER)


def test_session_of():
    assert driver.session_of(P3_LOCALIZER) == SCAN + "PRISMA3QC/2026.11.11-06.27.15"
    assert driver.session_of(P1_BOLD) == SCAN + "homeless/Brain^Prisma1QC/2026.11.12-06.20.29"

def fake_result(ok, z):
    """What shim.check() hands back, made up for a test."""
    return {"scanner": "P2", "station": "AWP167046", "z": z, "threshold": 4505.26, "ok": ok}


def test_shim_message():
    session = SCAN + "homeless/Brain^Prisma2QC/2026.11.12-06.24.18"

    subject, body = driver.shim_message(fake_result(True, 4527.0), session)
    assert subject == "✅ P2 z ShimQA okay"
    assert body == "P2 ✅: z=4527.00 ≥ 4505.26 – value okay.\nSession: homeless/Brain^Prisma2QC/2026.11.12-06.24.18"

    subject, body = driver.shim_message(fake_result(False, 4425.0), session)
    assert subject == "⛔ P2 z ShimQA BAD"
    assert body == "P2 ⛔: z=4425.00 < 4505.26 – BAD SHIM\nSession: homeless/Brain^Prisma2QC/2026.11.12-06.24.18"


def test_check_shim_logs_pass_and_fail(monkeypatch, caplog):
    caplog.set_level("INFO")

    def passing(path):
        return fake_result(True, 4527.0)

    def failing(path):
        return fake_result(False, 4425.0)

    monkeypatch.setattr(driver.shim, "check", passing)
    driver.check_shim("any.dcm")
    assert "shim PASS: P2 z=4527.00 threshold=4505.26" in caplog.text

    monkeypatch.setattr(driver.shim, "check", failing)
    driver.check_shim("any.dcm")
    assert "shim FAIL: P2 z=4425.00 threshold=4505.26" in caplog.text

P3_LOCALIZER_2 = SCAN + "PRISMA3QC/2026.11.11-06.27.15/PRISMA3QA20261111/localizer_256x256.2"


def new_state():
    return {"cutoff": 0, "retry": {}, "done": {}}


def use_fakes(monkeypatch):
    """Swap shim.check, tsnr.run and send_email for stand-ins that note down each call."""
    calls = {"shim": [], "tsnr": [], "email": []}

    def fake_check(path):
        calls["shim"].append(path)
        return fake_result(True, 4527.0)

    def fake_tsnr(path):
        calls["tsnr"].append(path)
        return "/out/folder"

    def fake_send(subject, body):
        calls["email"].append(subject)

    monkeypatch.setattr(driver.shim, "check", fake_check)
    monkeypatch.setattr(driver.tsnr, "run", fake_tsnr)
    monkeypatch.setattr(driver, "send_email", fake_send)
    return calls


def test_shim_is_checked_once_per_session(monkeypatch):
    calls = use_fakes(monkeypatch)
    state = new_state()
    driver.handle_series(P3_LOCALIZER, "one.dcm", state, 100)
    driver.handle_series(P3_LOCALIZER_2, "two.dcm", state, 100)
    assert calls["shim"] == ["one.dcm"]
    assert state["done"] == {SCAN + "PRISMA3QC/2026.11.11-06.27.15": 100}


def test_human_series_is_ignored(monkeypatch):
    calls = use_fakes(monkeypatch)
    state = new_state()
    driver.handle_series(HUMAN, "x.dcm", state, 100)
    assert calls == {"shim": [], "tsnr": [], "email": []}
    assert state["done"] == {}


def test_bold_runs_tsnr_only_when_switched_on(monkeypatch):
    calls = use_fakes(monkeypatch)

    monkeypatch.setattr(driver, "RUN_TSNR", False)
    driver.handle_series(P1_BOLD, "bold.dcm", new_state(), 100)
    assert calls["tsnr"] == []

    monkeypatch.setattr(driver, "RUN_TSNR", True)
    driver.handle_series(P1_BOLD, "bold.dcm", new_state(), 100)
    assert calls["tsnr"] == ["bold.dcm"]
    assert calls["shim"] == []


def test_email_is_sent_only_when_switched_on(monkeypatch):
    calls = use_fakes(monkeypatch)

    monkeypatch.setattr(driver, "SEND_EMAIL", False)
    driver.handle_series(P3_LOCALIZER, "one.dcm", new_state(), 100)
    assert calls["email"] == []

    monkeypatch.setattr(driver, "SEND_EMAIL", True)
    driver.handle_series(P3_LOCALIZER, "one.dcm", new_state(), 100)
    assert calls["email"] == ["✅ P2 z ShimQA okay"]


def test_series_without_shim_value_leaves_session_open(monkeypatch):
    use_fakes(monkeypatch)

    def no_value(path):
        raise ValueError("no CSA header")

    monkeypatch.setattr(driver.shim, "check", no_value)
    state = new_state()
    driver.handle_series(P3_LOCALIZER, "one.dcm", state, 100)
    assert state["done"] == {}

def run_main(monkeypatch, state, found, failing):
    """Run driver.main() once, with the poller and handle_series swapped for stand-ins.
    Returns the list of series main() tried to handle."""
    handled = []

    def fake_lock():
        return None

    def fake_load():
        return state

    def fake_find_new(state, now):
        return found, {}, 500.0

    def fake_save(state):
        pass

    def fake_first_dicom(series_dir):
        return series_dir + "/MR.1"

    def fake_handle(series_dir, dcm_path, state, now):
        handled.append(series_dir)
        if series_dir in failing:
            raise RuntimeError("test failure")

    monkeypatch.setattr(driver.poller, "acquire_lock", fake_lock)
    monkeypatch.setattr(driver.poller, "load_state", fake_load)
    monkeypatch.setattr(driver.poller, "find_new", fake_find_new)
    monkeypatch.setattr(driver.poller, "save_state", fake_save)
    monkeypatch.setattr(driver.poller, "first_dicom", fake_first_dicom)
    monkeypatch.setattr(driver, "handle_series", fake_handle)
    driver.main()
    return handled


def test_failed_series_is_retried_then_given_up(monkeypatch):
    state = new_state()
    run_main(monkeypatch, state, found={P1_BOLD: "bold.dcm"}, failing=[P1_BOLD])
    assert state["retry"] == {P1_BOLD: 1}
    run_main(monkeypatch, state, found={}, failing=[P1_BOLD])
    assert state["retry"] == {P1_BOLD: 2}
    run_main(monkeypatch, state, found={}, failing=[P1_BOLD])
    assert state["retry"] == {}


def test_retried_series_that_works_leaves_the_list(monkeypatch):
    state = new_state()
    state["retry"] = {P1_BOLD: 1}
    handled = run_main(monkeypatch, state, found={}, failing=[])
    assert handled == [P1_BOLD]
    assert state["retry"] == {}
    assert state["cutoff"] == 500.0


def test_one_failure_does_not_stop_the_others(monkeypatch):
    state = new_state()
    found = {P1_BOLD: "bold.dcm", P3_LOCALIZER: "one.dcm"}
    handled = run_main(monkeypatch, state, found, failing=[P1_BOLD])
    assert handled == sorted([P1_BOLD, P3_LOCALIZER])
    assert state["retry"] == {P1_BOLD: 1}


def test_old_sessions_are_forgotten(monkeypatch):
    state = new_state()
    state["done"] = {"/old/session": 1000, "/new/session": time.time()}
    run_main(monkeypatch, state, found={}, failing=[])
    assert list(state["done"]) == ["/new/session"]
