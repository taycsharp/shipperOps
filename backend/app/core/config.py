from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://shipper:shipper_password@localhost:5432/shipper_db"
    jwt_secret: str = "change_this_super_secret_key"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440
    cors_origins: str = "http://localhost:3000"
    environment: str = "development"
    create_all_on_startup: bool = False
    upload_folder: str = "./uploads"
    upload_max_file_mb: int = 5

    class Config:
        env_file = ".env"


settings = Settings()
