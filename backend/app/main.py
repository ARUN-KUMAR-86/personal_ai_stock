"""Main FastAPI application entrypoint."""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.logging import logger
from app.database.session import init_db
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


@app.get("/")
def root():
    return {
        "app": settings.APP_NAME,
        "version": "1.0.0",
        "docs_url": "/docs",
        "health_check": f"{settings.API_V1_STR}/health",
        "market_status": f"{settings.API_V1_STR}/market-status",
    }


@app.get("/health")
def cloud_health_check():
    """Standard cloud root health-check endpoint for Render / AWS / GCP container probes."""
    return {
        "status": "healthy",
        "app_name": settings.APP_NAME,
        "environment": settings.ENVIRONMENT,
        "auto_scan_enabled": settings.AUTO_SCAN_ENABLED,
    }
