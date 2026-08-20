import os
import logging

os.environ["HF_HOME"] = "/tmp/hf_cache"

from fastapi import FastAPI, HTTPException, status, UploadFile, File, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from faster_whisper import WhisperModel
from models import Session, ChatContinueRequest, ChatContinueResponse, AudioChunkResponse, LocalLanguageBaseline, CorporateEnglishBaseline
from session_manager import SessionManager
from services.gemma12b_service import Gemma12BService
from services.tts_service import TTSService

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("voice_assistant_backend")

app = FastAPI(
    title="Voice-Assisted Question & Answer Editor Backend",
    version="1.2.0",
    description="E12B backend service wrapping Gemma 12B context refinement, multi-lingual audio chunk buffering, CUDA GPU STT, sovereign TTS, and session state manager for E4B client."
)

# Enable CORS for mobile client WAN access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static audio outputs directory for sovereign TTS voice playback
os.makedirs("/tmp/audio_outputs", exist_ok=True)
app.mount("/audio", StaticFiles(directory="/tmp/audio_outputs"), name="audio")

session_manager = SessionManager()
gemma12b_service = Gemma12BService()
tts_service = TTSService()

# Initialize Faster-Whisper AI Model with CUDA GPU Acceleration
logger.info("Initializing Faster-Whisper AI model...")
device_choice = "cuda" if os.system("nvidia-smi >/dev/null 2>&1") == 0 else "cpu"
compute_choice = "float16" if device_choice == "cuda" else "int8"
logger.info(f"Faster-Whisper selecting device: {device_choice} ({compute_choice})")

try:
    whisper_model = WhisperModel("base", device=device_choice, compute_type=compute_choice, download_root="/tmp/hf_cache")
except Exception as e:
    logger.warning(f"CUDA initialization fallback to CPU: {e}")
    whisper_model = WhisperModel("base", device="cpu", compute_type="int8", download_root="/tmp/hf_cache")

logger.info(f"Faster-Whisper AI model ready on {device_choice}.")

@app.get("/api/v1/health")
def health_check():
    return {
        "status": "ok",
        "service": "E12B Voice Assistant Backend",
        "gemma12b": "ready",
        "stt": "whisper",
        "device": device_choice,
        "dual_baseline": True,
        "sovereign_tts": True
    }

@app.post("/api/v1/tts/synthesize")
def synthesize_tts(thread_id: str, text: str):
    """
    Synthesizes sovereign local voice audio for question prompts and returns local playback URL.
    """
    audio_url = tts_service.synthesize_question_audio(thread_id, text)
    return {"thread_id": thread_id, "audio_url": audio_url}

@app.get("/api/v1/session/{session_id}", response_model=Session)
def get_session(session_id: str):
    try:
        return session_manager.get_or_create_default_session(session_id)
    except Exception as e:
        logger.error(f"Error fetching session {session_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/session", response_model=Session)
def create_or_init_session(session_id: str = "sess_default"):
    return session_manager.get_or_create_default_session(session_id)

@app.post("/api/v1/session/{session_id}/reset", response_model=Session)
def reset_session(session_id: str):
    """
    Resets Q&A status back to the pristine start state (0 answers, thr_101 active as Question 1).
    """
    try:
        return session_manager.reset_session_to_pristine_start(session_id)
    except Exception as e:
        logger.error(f"Error resetting session {session_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/session/{session_id}/thread/{thread_id}/clear", response_model=Session)
def clear_thread(session_id: str, thread_id: str):
    try:
        return session_manager.clear_thread_answers(session_id, thread_id)
    except Exception as e:
        logger.error(f"Error clearing thread {thread_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/session/{session_id}/thread/{thread_id}/delete-last-segment", response_model=Session)
def delete_last_segment(session_id: str, thread_id: str):
    try:
        return session_manager.delete_last_segment(session_id, thread_id)
    except Exception as e:
        logger.error(f"Error deleting last segment in thread {thread_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/session/{session_id}/thread/{thread_id}/adjust", response_model=Session)
def adjust_answer(session_id: str, thread_id: str, instruction: str = Query("")):
    """
    Executes a voice or text command instruction against the existing answer baseline.
    Does NOT append instruction text to the answer.
    """
    try:
        return session_manager.adjust_answer(session_id, thread_id, instruction, gemma12b_service)
    except Exception as e:
        logger.error(f"Error adjusting answer in thread {thread_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/session/{session_id}/thread/{thread_id}/ai-answer", response_model=Session)
def generate_ai_answer(session_id: str, thread_id: str):
    """
    Generates an expert answer to the question using Gemini / Gemma 12B assuming the persona of a
    Finance Specialist in the Systems Integration business in the interview language.
    """
    try:
        return session_manager.generate_ai_answer(session_id, thread_id, gemma12b_service)
    except Exception as e:
        logger.error(f"Error generating AI answer in thread {thread_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/session/{session_id}/thread/{thread_id}/ai-answer/stream")
def stream_ai_answer(session_id: str, thread_id: str, sentence_count: int = Query(3)):
    """
    Streams the generated AI answer chunk by chunk via SSE and saves the completed text to the session database.
    """
    from fastapi.responses import StreamingResponse
    session = session_manager.get_session(session_id)
    target_thread = next((t for t in session.question_threads if t.thread_id == thread_id), None)
    question_text = target_thread.question_text if target_thread else ""

    def event_generator():
        accumulated = ""
        for chunk in gemma12b_service.stream_ai_answer(question_text, sentence_count=sentence_count):
            accumulated += chunk
            yield chunk
        if accumulated.strip():
            session_manager.add_ai_answer_direct(session_id, thread_id, accumulated.strip())

    return StreamingResponse(event_generator(), media_type="text/plain")

@app.post("/api/v1/session/{session_id}/thread/{thread_id}/accept", response_model=Session)
def accept_thread(session_id: str, thread_id: str):
    """
    Locks local language baseline, runs translation to Corporate English Baseline,
    locks corporate baseline as read-only (editable=False), and promotes next upcoming question.
    """
    try:
        return session_manager.accept_question_thread(session_id, thread_id)
    except Exception as e:
        logger.error(f"Error accepting thread {thread_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/audio/stream-chunk", response_model=AudioChunkResponse)
async def stream_audio_chunk(
    session_id: str,
    thread_id: str,
    chunk_seq: int,
    language_code: str = "auto",
    file: UploadFile = File(...)
):
    """
    Ingests continuous audio stream chunk from E4B frontend, appends to E12B disk buffer,
    concatenates continuous audio recording, and runs multi-lingual STT to update Local Language Baseline.
    """
    buffer_dir = f"/tmp/audio_buffers/{session_id}/{thread_id}"
    os.makedirs(buffer_dir, exist_ok=True)
    chunk_path = os.path.join(buffer_dir, f"chunk_{chunk_seq:04d}.wav")

    try:
        content = await file.read()
        with open(chunk_path, "wb") as f:
            f.write(content)

        # Gather all sequential chunks and combine for continuous STT
        chunk_files = sorted([os.path.join(buffer_dir, f) for f in os.listdir(buffer_dir) if f.startswith("chunk_") and f.endswith(".wav")])
        combined_path = os.path.join(buffer_dir, "compiled_local.wav")
        
        with open(combined_path, "wb") as outfile:
            for c_file in chunk_files:
                with open(c_file, "rb") as infile:
                    outfile.write(infile.read())

        # Run multi-lingual transcription
        lang_arg = None if language_code == "auto" else language_code
        segments, info = whisper_model.transcribe(combined_path, beam_size=5, language=lang_arg)
        transcript_text = " ".join([segment.text for segment in segments]).strip()
        detected_lang = info.language if hasattr(info, 'language') else language_code

        logger.info(f"StreamChunk Received: Chunk #{chunk_seq} for {session_id}/{thread_id} -> Transcript ({detected_lang}): '{transcript_text}'")

        local_baseline = LocalLanguageBaseline(
            language_code=detected_lang,
            transcript=transcript_text,
            compiled_audio_url=f"/media/{session_id}/{thread_id}/compiled_local.wav",
            chunk_count=len(chunk_files),
            status="COMPILED"
        )

        # Refine output using Gemma 12B
        session = session_manager.get_or_create_default_session(session_id)
        target_thread = next((t for t in session.question_threads if t.thread_id == thread_id), None)
        prior_answers = target_thread.answers if target_thread else []

        refined_output = gemma12b_service.refine_input(
            question_text=target_thread.question_text if target_thread else "",
            prior_answers=prior_answers,
            new_transcript=transcript_text
        )

        session_manager.add_answer(
            session_id=session_id,
            thread_id=thread_id,
            e4b_transcript=transcript_text,
            gemma12b_output=refined_output,
            local_baseline=local_baseline
        )

        return AudioChunkResponse(
            session_id=session_id,
            thread_id=thread_id,
            chunk_seq=chunk_seq,
            language_code=detected_lang,
            local_transcript=transcript_text,
            status="COMPILED"
        )

    except Exception as e:
        logger.error(f"Error streaming audio chunk #{chunk_seq}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/audio/transcribe")
async def transcribe_audio(file: UploadFile = File(...), language_code: str = Query("auto")):
    """
    Transcribes uploaded WAV audio file using faster-whisper AI engine.
    Returns exact spoken transcript.
    """
    temp_path = f"/tmp/uploaded_{file.filename}"
    try:
        content = await file.read()
        with open(temp_path, "wb") as f:
            f.write(content)

        lang_arg = None if language_code == "auto" else language_code
        segments, info = whisper_model.transcribe(temp_path, beam_size=1, language=lang_arg)
        text = " ".join([segment.text for segment in segments]).strip()

        if not text:
            logger.warning("Whisper transcribed audio but detected zero speech tokens.")
            raise HTTPException(status_code=400, detail="No speech detected in audio recording.")

        logger.info(f"Whisper Transcribed Audio Success ({info.language if hasattr(info, 'language') else 'auto'}): '{text}'")
        return {"status": "success", "transcript": text, "language": info.language if hasattr(info, 'language') else "auto"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Whisper Audio Transcription Error: {e}")
        raise HTTPException(status_code=500, detail=f"Transcription error: {e}")
    finally:
        if os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception:
                pass

@app.post("/api/v1/chat/continue", response_model=ChatContinueResponse)
def continue_chat(req: ChatContinueRequest):
    try:
        session = session_manager.get_or_create_default_session(req.session_id)
        
        target_thread = None
        for thread in session.question_threads:
            if thread.thread_id == req.thread_id:
                target_thread = thread
                break
        
        if not target_thread:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Thread {req.thread_id} not found in session {req.session_id}."
            )

        refined_output = gemma12b_service.refine_input(
            question_text=target_thread.question_text,
            prior_answers=target_thread.answers,
            new_transcript=req.e4b_transcript
        )

        loc_baseline = LocalLanguageBaseline(
            language_code="auto",
            transcript=req.e4b_transcript,
            status="COMPILED"
        )
        corp_baseline = CorporateEnglishBaseline(
            language_code="en-US",
            transcript=refined_output,
            status="READY",
            editable=True
        )

        new_answer = session_manager.add_answer(
            session_id=req.session_id,
            thread_id=req.thread_id,
            e4b_transcript=req.e4b_transcript,
            gemma12b_output=refined_output,
            local_baseline=loc_baseline,
            corporate_baseline=corp_baseline
        )

        return ChatContinueResponse(
            session_id=req.session_id,
            thread_id=req.thread_id,
            seq=new_answer.seq,
            e4b_transcript=new_answer.e4b_transcript,
            gemma12b_output=new_answer.gemma12b_output,
            local_language_baseline=new_answer.local_language_baseline,
            corporate_english_baseline=new_answer.corporate_english_baseline,
            recorded_at=new_answer.recorded_at
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error processing chat continue: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8080, reload=True)
