import json

import lightgbm as lgb
import numpy as np
import pytest

from backend.app.features import FEATURE_NAMES
from backend.app.tier2 import LightGBMTier2Model


def _write_dummy_model(tmp_path, feature_names=None):
    feature_names = feature_names if feature_names is not None else list(FEATURE_NAMES)
    n = 60
    X = np.array([[float(i % 5)] * len(feature_names) for i in range(n)])
    y = np.array([i % 2 for i in range(n)])
    dataset = lgb.Dataset(X, label=y, feature_name=feature_names)
    model = lgb.train(
        {"objective": "binary", "verbosity": -1, "min_data_in_leaf": 5},
        dataset,
        num_boost_round=5,
    )
    model_dir = tmp_path / "model"
    model_dir.mkdir()
    model.save_model(str(model_dir / "model.txt"))
    (model_dir / "feature_names.json").write_text(json.dumps(feature_names))
    (model_dir / "metrics.json").write_text(json.dumps({"pr_auc": 0.5}))
    return model_dir


def test_loads_and_predicts_within_bounds(tmp_path):
    model_dir = _write_dummy_model(tmp_path)
    model = LightGBMTier2Model(str(model_dir))
    features = {name: 1.0 for name in FEATURE_NAMES}
    p = model.predict(features)
    assert 0.0 <= p <= 1.0


def test_missing_model_file_raises(tmp_path):
    empty_dir = tmp_path / "empty"
    empty_dir.mkdir()
    (empty_dir / "feature_names.json").write_text(json.dumps(list(FEATURE_NAMES)))
    with pytest.raises(FileNotFoundError):
        LightGBMTier2Model(str(empty_dir))


def test_feature_list_mismatch_refuses_to_load(tmp_path):
    wrong_features = list(FEATURE_NAMES)[:-1]  # drop one — deliberately mismatched
    model_dir = _write_dummy_model(tmp_path, feature_names=wrong_features)
    with pytest.raises(ValueError, match="feature list"):
        LightGBMTier2Model(str(model_dir))


def test_predict_raises_on_missing_feature_key(tmp_path):
    model_dir = _write_dummy_model(tmp_path)
    model = LightGBMTier2Model(str(model_dir))
    incomplete_features = {name: 1.0 for name in list(FEATURE_NAMES)[:-1]}
    with pytest.raises(KeyError):
        model.predict(incomplete_features)
