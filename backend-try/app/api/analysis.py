from fastapi import APIRouter, HTTPException

from app.schemas.transcript import AnalysisResponse, TranscriptRequest
from app.services.nlp import analyze_transcript

router = APIRouter(tags=["analysis"])


@router.post("/analyze", response_model=AnalysisResponse)
async def analyze(request: TranscriptRequest):
    """Analyze a transcript and return structured insights.

    Accepts transcript text and returns:
    - Summary
    - Key points
    - Action items
    - Topics
    - Keywords
    """
    try:
        result = await analyze_transcript(request.transcript)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")
