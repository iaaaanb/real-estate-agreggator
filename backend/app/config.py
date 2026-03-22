from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "development"
    app_secret_key: str = "cambia-esto"

    # Postgres
    database_url: str = "postgresql+asyncpg://propiedades:devpass123@localhost:5432/propiedades"
    database_url_sync: str = "postgresql://propiedades:devpass123@localhost:5432/propiedades"

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # MercadoLibre
    ml_client_id: str = ""
    ml_client_secret: str = ""
    ml_redirect_uri: str = "http://localhost:8000/api/v1/auth/callback"
    ml_api_base: str = "https://api.mercadolibre.com"
    ml_site_id: str = "MLC"

    # Categorías ML para inmuebles en Chile
    ml_real_estate_category: str = "MLC1459"

    @property
    def is_dev(self) -> bool:
        return self.app_env == "development"


settings = Settings()
