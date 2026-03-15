from pydantic import BaseModel, Field


class TranscriptRequest(BaseModel):
    """Request body for transcript analysis."""

    transcript: str = Field(
        ...,
        min_length=10,
        description="The transcript text to analyze",
        examples=["Today we discussed the Q4 roadmap. John will handle the frontend redesign by March 15. Sarah is taking over the API migration. Key decision: we're switching from REST to GraphQL."],
    )


class AnalysisResponse(BaseModel):
    """Structured insights extracted from a transcript."""

    summary: str = Field(
        ...,
        description="A concise summary of the transcript",
    )
    key_points: list[str] = Field(
        default_factory=list,
        description="The most important points discussed",
    )
    action_items: list[str] = Field(
        default_factory=list,
        description="Tasks or follow-ups assigned to people",
    )
    topics: list[str] = Field(
        default_factory=list,
        description="Main topics or themes covered",
    )
    keywords: list[str] = Field(
        default_factory=list,
        description="Important keywords and terms",
    )
