"""Main FastAPI application entrypoint."""

import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, HTMLResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.logging import logger
from app.database.session import init_db, get_db
from app.scanner.scheduler import start_scheduler, shutdown_scheduler

# Routers
from app.api.v1.auth import router as auth_router
from app.api.v1.health import router as health_router
from app.api.v1.stocks import router as stocks_router
from app.api.v1.scanner import router as scanner_router
from app.api.v1.signals import router as signals_router
from app.api.v1.alerts import router as alerts_router
from app.api.v1.portfolio import router as portfolio_router
from app.api.v1.funds import router as funds_router
from app.api.v1.groww import router as groww_router
from app.api.v1.backtest import router as backtest_router
from app.api.v1.orders import router as orders_router
from app.api.v1.safety import router as safety_router
from app.api.v1.watchlist import router as watchlist_router
from app.api.v1.trading_control import router as trading_control_router



@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle event handler for application startup and shutdown."""
    logger.info(f"Starting {settings.APP_NAME}...")
    init_db()
    start_scheduler()
    yield
    logger.info(f"Shutting down {settings.APP_NAME}...")
    shutdown_scheduler()


app = FastAPI(
    title=settings.APP_NAME,
    description=(
        "Personal AI Stock Intelligence & Android Notification System.\n\n"
        "Provides market scanning, transparent rule-based quantitative strategies, "
        "portfolio risk controls, Groww broker integration, paper trading, and Firebase Cloud Messaging alerts."
    ),
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount API Routers
app.include_router(health_router, prefix=settings.API_V1_STR)
app.include_router(auth_router, prefix=settings.API_V1_STR)
app.include_router(stocks_router, prefix=settings.API_V1_STR)
app.include_router(scanner_router, prefix=settings.API_V1_STR)
app.include_router(signals_router, prefix=settings.API_V1_STR)
app.include_router(alerts_router, prefix=settings.API_V1_STR)
app.include_router(portfolio_router, prefix=settings.API_V1_STR)
app.include_router(funds_router, prefix=settings.API_V1_STR)
app.include_router(groww_router, prefix=settings.API_V1_STR)
app.include_router(backtest_router, prefix=settings.API_V1_STR)
app.include_router(orders_router, prefix=settings.API_V1_STR)
app.include_router(safety_router, prefix=settings.API_V1_STR)
app.include_router(watchlist_router, prefix=settings.API_V1_STR)
app.include_router(trading_control_router, prefix=settings.API_V1_STR)


# Mount Static Files & Web Dashboard
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")


class SettingItem(BaseModel):
    key: str
    value: str


@app.get(f"{settings.API_V1_STR}/settings")
def list_settings(db: Session = Depends(get_db)):
    """Retrieves all runtime configuration settings."""
    from app.models.setting import AppSetting
    records = db.query(AppSetting).all()
    res = {r.key: r.value for r in records}
    if "PREFERRED_HORIZON" not in res:
        res["PREFERRED_HORIZON"] = "ALL"
    if "PREFERRED_MARKET" not in res:
        res["PREFERRED_MARKET"] = "ALL"
    if "GEMINI_MODEL" not in res:
        res["GEMINI_MODEL"] = "gemini-3.5-flash-lite"

    raw_key = res.get("GEMINI_API_KEY")
    res["GEMINI_CONFIGURED"] = bool(raw_key)
    if raw_key and len(raw_key) > 8:
        res["GEMINI_API_KEY_MASKED"] = f"{raw_key[:4]}...{raw_key[-4:]}"
    else:
        res["GEMINI_API_KEY_MASKED"] = None
    return res


@app.post(f"{settings.API_V1_STR}/settings")
def update_setting(item: SettingItem, db: Session = Depends(get_db)):
    """Updates runtime configuration settings (e.g. GEMINI_API_KEY)."""
    from app.models.setting import AppSetting
    record = db.query(AppSetting).filter(AppSetting.key == item.key).first()
    if record:
        record.value = item.value
    else:
        record = AppSetting(key=item.key, value=item.value)
        db.add(record)
    db.commit()
    return {"status": "SUCCESS", "key": item.key}


@app.get(f"{settings.API_V1_STR}/settings/{{key}}")
def get_setting(key: str, db: Session = Depends(get_db)):
    """Retrieves runtime configuration setting."""
    from app.models.setting import AppSetting
    record = db.query(AppSetting).filter(AppSetting.key == key).first()
    if not record:
        return {"key": key, "value": None}
    return {"key": key, "value": record.value}


@app.get("/", response_class=HTMLResponse)
def root(request: Request):
    accept = request.headers.get("accept", "")
    index_file = os.path.join(static_dir, "index.html")
    if "text/html" in accept and os.path.exists(index_file):
        return FileResponse(index_file)
    return {
        "app": settings.APP_NAME,
        "version": "1.0.0",
        "docs_url": "/docs",
        "health_check": f"{settings.API_V1_STR}/health",
        "alerts_stream": f"{settings.API_V1_STR}/alerts/stream",
    }


@app.get("/dashboard", response_class=HTMLResponse)
def dashboard():
    index_file = os.path.join(static_dir, "index.html")
    if os.path.exists(index_file):
        return FileResponse(index_file)
    return HTMLResponse("<h1>AI Stock Intelligence Dashboard</h1>")


@app.get("/health")
def cloud_health_check():
    """Standard cloud root health-check endpoint for Render / AWS / GCP container probes."""
    return {
        "status": "healthy",
        "app_name": settings.APP_NAME,
        "environment": settings.ENVIRONMENT,
        "auto_scan_enabled": settings.AUTO_SCAN_ENABLED,
    }
