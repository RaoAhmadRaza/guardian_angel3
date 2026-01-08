"""
Arrhythmia Inference Service - FastAPI Application

Local-only inference service for arrhythmia risk detection.
Runs the trained XGBoost model unchanged.

Usage:
    uvicorn main:app --host 127.0.0.1 --port 8000

Or for development:
    python main.py
"""

import logging
import sys
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routes import router
from config import settings
from core.predictor import load_predictor, ModelLoadError


# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================

logging.basicConfig(
    level=getattr(logging, settings.log_level.upper()),
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
    handlers=[logging.StreamHandler(sys.stdout)],
)

logger = logging.getLogger(__name__)


# =============================================================================
# APPLICATION LIFESPAN
# =============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan manager.
    
    Loads the model at startup and cleans up at shutdown.
    """
    # Startup
    logger.info("=" * 60)
    logger.info("Guardian Angel - Arrhythmia Inference Service")
    logger.info("=" * 60)
    logger.info(f"Host: {settings.host}:{settings.port}")
    logger.info(f"Model path: {settings.model_file}")
    logger.info(f"Debug mode: {settings.debug}")
    
    try:
        predictor = load_predictor()
        logger.info(f"Model loaded successfully")
        logger.info(f"  Version: {predictor.model_version}")
        logger.info(f"  Hash: sha256:{predictor.model_hash}")
        logger.info(f"  Features: {predictor.feature_count}")
    except ModelLoadError as e:
        logger.error(f"Failed to load model: {e}")
        logger.warning("Service will start but inference will be unavailable")
    
    logger.info("=" * 60)
    logger.info("Service ready. Accepting connections on localhost only.")
    logger.info("=" * 60)
    
    yield
    
    # Shutdown
    logger.info("Shutting down...")


# =============================================================================
# FASTAPI APPLICATION
# =============================================================================

app = FastAPI(
    title="Arrhythmia Inference Service",
    description=(
        "Local-only inference service for arrhythmia risk detection. "
        "Uses a trained XGBoost model to analyze HRV features extracted from RR intervals."
    ),
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
)


# =============================================================================
# MIDDLEWARE
# =============================================================================

# CORS - restrict to localhost only
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:*",
        "http://127.0.0.1:*",
    ],
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


# =============================================================================
# ROUTES
# =============================================================================

app.include_router(router)


# Root endpoint
@app.get("/", include_in_schema=False)
async def root():
    """Root endpoint - service info."""
    return {
        "service": "arrhythmia-inference",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs" if settings.debug else "disabled",
    }


# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
        log_level=settings.log_level.lower(),
    )
