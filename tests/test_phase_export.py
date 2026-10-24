import numpy as np
import pytest

lgb = pytest.importorskip("lightgbm")

from ml.rig.export_app import MODEL_DIR, eval_exported, export_booster  # noqa: E402


@pytest.mark.parametrize("name", ["level_model.txt", "others_model.txt"])
def test_exported_trees_give_the_same_probabilities_as_lightgbm(name):
    booster = lgb.Booster(model_file=str(MODEL_DIR / name))
    exported = export_booster(MODEL_DIR / name)
    n_features = booster.num_feature()
    rng = np.random.default_rng(11)
    X = rng.normal(loc=[1.5, 0.0, 200.0, 500.0, 2.0, 0.3][:n_features], scale=[2.0, 0.5, 80.0, 40.0, 3.0, 0.3][:n_features], size=(300, n_features))
    expected = booster.predict(X)
    for row, want in zip(X, expected):
        got = eval_exported(exported, list(row))
        assert got == pytest.approx(list(want), abs=1e-9)
