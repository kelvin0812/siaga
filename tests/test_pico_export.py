import json

import pytest

lgb = pytest.importorskip("lightgbm")

from ml.rig.export_app import APP_FIXTURE  # noqa: E402
from ml.rig.export_pico import PortEngine, forest_proba, load_parts, render_model_header, render_selftest_header  # noqa: E402


@pytest.fixture(scope="module")
def parts():
    return load_parts()


def test_flat_arrays_give_the_same_probabilities_as_lightgbm(parts):
    meta, level, others = parts
    from ml.rig.export_app import MODEL_DIR

    booster = lgb.Booster(model_file=str(MODEL_DIR / "level_model.txt"))
    import numpy as np

    rng = np.random.default_rng(5)
    X = rng.normal(loc=[1.5, 0.0], scale=[2.0, 0.6], size=(200, 2))
    for row, want in zip(X, booster.predict(X)):
        assert forest_proba(level, list(row)) == pytest.approx(list(want), abs=1e-9)


def test_port_of_the_pico_engine_reproduces_the_python_answers_on_real_rows(parts):
    meta, level, others = parts
    cases = json.loads(APP_FIXTURE.read_text(encoding="utf-8"))["cases"]
    compared = 0
    for case in cases:
        eng = PortEngine(meta, level, others)
        for r, e in zip(case["rows"], case["expected"]):
            got = eng.update(r["t"], r["dist"], r["flow"], r["soil"], *r["accel"], *r["gyro"])
            if e is None:
                assert got is None
                continue
            assert got is not None
            assert got[0] == e["phase"] and got[1] == e["raw"]
            assert got[2] == pytest.approx(e["probs"], abs=1e-9)
            compared += 1
    assert compared > 400


def test_generated_headers_contain_the_model_and_the_self_test(parts):
    meta, level, others = parts
    model_h = render_model_header(meta, level, others)
    assert "static const PhaseForest LEVEL" in model_h and "static const PhaseForest OTHERS" in model_h
    assert f"{{ {level['num_trees']}," in model_h
    cases = json.loads(APP_FIXTURE.read_text(encoding="utf-8"))["cases"]
    test_h = render_selftest_header([{"rows": c["rows"][:20], "expected": c["expected"][:20]} for c in cases])
    assert "SELFTEST_ROWS" in test_h and "SELFTEST_EXPECT" in test_h
