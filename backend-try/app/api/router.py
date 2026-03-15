from fastapi import APIRouter

from app.api.analysis import router as analysis_router

router = APIRouter()

router.include_router(analysis_router)


@router.get("/")
async def root():
    return {"message": "AURA API is running"}
