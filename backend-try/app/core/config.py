from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    gemini_api_key: str = ""
    app_name: str = "AURA Backend"
    debug: bool = False

    model_config = {"env_file": ".env"}


settings = Settings()
