from typing import List, Optional
from pydantic import BaseModel, Field
from datetime import datetime

class LocalLanguageBaseline(BaseModel):
    language_code: str = "auto"
    transcript: str = ""
    compiled_audio_url: Optional[str] = None
    chunk_count: int = 0
    total_duration_seconds: float = 0.0
    status: str = Field(default="RECORDING", description="RECORDING | COMPILED | LOCKED")

class CorporateEnglishBaseline(BaseModel):
    language_code: str = "en-US"
    transcript: str = ""
    status: str = Field(default="PENDING", description="PENDING | TRANSLATING | LOCKED")
    editable: bool = False
    translated_at: Optional[str] = None

class AnswerEntry(BaseModel):
    seq: int
    e4b_transcript: str
    gemma12b_output: str
    tts_audio_path: Optional[str] = None
    local_language_baseline: Optional[LocalLanguageBaseline] = None
    corporate_english_baseline: Optional[CorporateEnglishBaseline] = None
    recorded_at: str

class QuestionThread(BaseModel):
    thread_id: str
    question_text: str
    status: str = Field(description="previous | current | upcoming")
    sort_order: int
    answers: List[AnswerEntry] = []

class Session(BaseModel):
    session_id: str
    question_threads: List[QuestionThread] = []

class AudioChunkRequest(BaseModel):
    session_id: str
    thread_id: str
    chunk_seq: int
    language_code: Optional[str] = "auto"

class AudioChunkResponse(BaseModel):
    session_id: str
    thread_id: str
    chunk_seq: int
    language_code: str
    local_transcript: str
    status: str

class ChatContinueRequest(BaseModel):
    session_id: str
    thread_id: str
    e4b_transcript: str
    audio_reference_url: Optional[str] = None

class ChatContinueResponse(BaseModel):
    session_id: str
    thread_id: str
    seq: int
    e4b_transcript: str
    gemma12b_output: str
    recorded_at: str

