from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.db import engine


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await engine.dispose()


app = FastAPI(
    title="Propiedades Chile API",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.frontend_url] if not settings.is_dev else ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
async def health():
    return {"status": "ok", "env": settings.app_env}


# Los routers se agregan en los siguientes pasos:
# from app.api import properties, alerts
# app.include_router(properties.router, prefix="/api/v1")
# app.include_router(alerts.router, prefix="/api/v1")
