"""Environment-driven settings (Section 10: secrets in env vars, never committed)."""
from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Empty DATABASE_URL means "run against InMemoryRepository" — the
    # offline demo fallback described in repository.py, not an error.
    database_url: str = ""

    mqtt_host: str = "localhost"
    mqtt_port: int = 8883
    mqtt_tls: bool = True
    mqtt_username: str = ""
    mqtt_password: str = ""

    # Path to a Firebase service account JSON. Empty means "no FCM
    # credentials configured" -> NullFCMClient (logs instead of sending),
    # so the backend still runs end to end without live push at the booth.
    firebase_credentials_path: str = ""

    density_min_subscribers: int = 10
    alert_buffer_rings: int = 2


settings = Settings()
