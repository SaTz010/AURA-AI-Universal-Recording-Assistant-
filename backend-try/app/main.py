from fastapi import FastAPI
from app.api.router import router as api_router

app = FastAPI(
    title="AURA - AI Universal Recording Assistant",
    description="Context-aware audio intelligence system. Processes transcripts into structured insights.",
    version="0.1.0",
)

app.include_router(api_router, prefix="/api")


@app.get("/")
async def root():
    return {
        "service": "AURA Backend",
        "version": "0.1.0",
        "docs": "/docs",
        "endpoints": {
            "analyze": "POST /api/analyze",
            "health": "GET /health",
        },
    }


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "AURA Backend"}
