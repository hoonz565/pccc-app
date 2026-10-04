from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: Literal["development", "test", "staging", "production"] = "development"
    api_host: str = "127.0.0.1"
    api_port: int = 8000
    database_url: str
    auth_signing_secret: SecretStr = Field(min_length=32)
    access_token_ttl_minutes: int = Field(default=15, ge=1, le=60)
    refresh_token_ttl_days: int = Field(default=30, ge=1, le=90)
    terms_version: str = Field(default="draft-v1", min_length=1, max_length=64)
    privacy_version: str = Field(default="draft-v1", min_length=1, max_length=64)
    ocr_engine: Literal["paddle"] = "paddle"
    ocr_max_image_bytes: int = Field(default=10 * 1024 * 1024, ge=1024, le=25 * 1024 * 1024)
    ocr_min_image_dimension: int = Field(default=32, ge=1, le=512)
    ocr_max_image_dimension: int = Field(default=12_000, ge=512, le=20_000)
    ocr_max_image_pixels: int = Field(default=40_000_000, ge=1_000_000, le=100_000_000)
    ocr_blur_warning_threshold: float = Field(default=50.0, ge=0)

    @property
    def is_development(self) -> bool:
        return self.app_env == "development"


@lru_cache
def get_settings() -> Settings:
    # Required values are supplied by BaseSettings environment sources at runtime.
    return Settings()  # type: ignore[call-arg]
