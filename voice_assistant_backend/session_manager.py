import sqlite3
import json
import logging
from datetime import datetime, timezone
from typing import Optional, List, Dict
from models import Session, QuestionThread, AnswerEntry, LocalLanguageBaseline, CorporateEnglishBaseline
from services.translation_service import TranslationService
from services.tts_service import TTSService

logger = logging.getLogger(__name__)

DB_PATH = "voice_session_store.db"

class SessionManager:
    def __init__(self, db_path: str = DB_PATH):
        self.db_path = db_path
        self.translation_service = TranslationService()
        self.tts_service = TTSService()
        self._init_db()

    def _get_connection(self):
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self):
        with self._get_connection() as conn:
            cursor = conn.cursor()
            # Sessions table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS sessions (
                    session_id TEXT PRIMARY KEY,
                    created_at TEXT NOT NULL
                )
            """)
            # Question Threads table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS question_threads (
                    thread_id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    question_text TEXT NOT NULL,
                    status TEXT NOT NULL,
                    sort_order INTEGER NOT NULL,
                    FOREIGN KEY (session_id) REFERENCES sessions (session_id)
                )
            """)
            # Answer Entries table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS answer_entries (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    thread_id TEXT NOT NULL,
                    seq INTEGER NOT NULL,
                    e4b_transcript TEXT NOT NULL,
                    gemma12b_output TEXT NOT NULL,
                    tts_audio_path TEXT,
                    local_language_json TEXT,
                    corporate_english_json TEXT,
                    recorded_at TEXT NOT NULL,
                    FOREIGN KEY (thread_id) REFERENCES question_threads (thread_id)
                )
            """)
            
            # Ensure columns exist if table was already created earlier
            cursor.execute("PRAGMA table_info(answer_entries)")
            columns = [col["name"] for col in cursor.fetchall()]
            if "local_language_json" not in columns:
                cursor.execute("ALTER TABLE answer_entries ADD COLUMN local_language_json TEXT")
            if "corporate_english_json" not in columns:
                cursor.execute("ALTER TABLE answer_entries ADD COLUMN corporate_english_json TEXT")

            # Audit log table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS audit_log (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    session_id TEXT NOT NULL,
                    thread_id TEXT NOT NULL,
                    action TEXT NOT NULL,
                    payload TEXT NOT NULL
                )
            """)
            conn.commit()

    def get_or_create_default_session(self, session_id: str = "sess_default") -> Session:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT session_id FROM sessions WHERE session_id = ?", (session_id,))
            row = cursor.fetchone()
            if not row:
                now_iso = datetime.now(timezone.utc).isoformat()
                cursor.execute("INSERT INTO sessions (session_id, created_at) VALUES (?, ?)", (session_id, now_iso))
                
                # Seed Process Improvement Assessment & Workflow Audit Questions
                default_questions = [
                    # 1 Active Current Question (First Question)
                    ("thr_101", "What standard operating metrics and value-stream mapping techniques do you use to identify processing bottlenecks in high-volume Accounts Payable workflows?", "current", 1),

                    # 14 Upcoming Process Improvement Questions
                    ("thr_102", "How do you streamline the 3-Way Matching exception process to increase touchless invoice processing rates above 95%?", "upcoming", 2),
                    ("thr_103", "What root-cause analysis methods (such as 5 Whys or Fishbone diagrams) do you execute when vendor payment discrepancies or duplicate payments occur?", "upcoming", 3),
                    ("thr_104", "How do you evaluate and optimize vendor payment terms (e.g., transitioning from Net 30 to dynamic 2/10 Net 30 discounting) to improve working capital yield?", "upcoming", 4),
                    ("thr_105", "How do you design and implement continuous improvement (Kaizen) cycles to optimize Accounts Payable SLA performance and reduce cost per invoice processed?", "upcoming", 5),
                    ("thr_106", "How do you optimize the Goods Received/Invoice Received (GR/IR) clearing process to minimize unvouched liabilities and month-end closing lag?", "upcoming", 6),
                    ("thr_107", "What process controls and automated validation rules do you implement to eliminate vendor master file duplication and bank routing fraud risk?", "upcoming", 7),
                    ("thr_108", "How do you restructure the employee expense management process (Concur/Expensify) to enforce policy compliance without delaying employee reimbursements?", "upcoming", 8),
                    ("thr_109", "How do you measure and reduce cycle time variation between paper-based invoice capture versus automated digital intake?", "upcoming", 9),
                    ("thr_110", "What process metrics and executive dashboards do you construct to provide real-time visibility into AP operational efficiency and cash outflow timing?", "upcoming", 10),
                    ("thr_111", "How do you streamline multi-currency cross-border payment processing to eliminate foreign exchange (FX) fee leakage and transfer delays?", "upcoming", 11),
                    ("thr_112", "What methodology do you follow to map, optimize, and standardize AP workflows during a post-merger ERP system consolidation?", "upcoming", 12),
                    ("thr_113", "How do you optimize 1099/1042-S tax compliance workflows to automate year-end vendor reporting with zero manual reconciliation?", "upcoming", 13),
                    ("thr_114", "How do you eliminate manual out-of-cycle emergency check requests by establishing standard SLA payment run schedules?", "upcoming", 14),
                    ("thr_115", "What process governance framework ensures continuous audit readiness for SOX 404 compliance without creating administrative drag?", "upcoming", 15),
                ]

                for thread_id, q_text, status, sort_order in default_questions:
                    cursor.execute(
                        "INSERT INTO question_threads (thread_id, session_id, question_text, status, sort_order) VALUES (?, ?, ?, ?, ?)",
                        (thread_id, session_id, q_text, status, sort_order)
                    )

                conn.commit()

        return self.get_session(session_id)

    def reset_session_to_pristine_start(self, session_id: str = "sess_default") -> Session:
        """
        Resets the entire Q&A session back to the beginning:
        0 answers, thr_101 as active CURRENT question, and all other questions as UPCOMING.
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM answer_entries")
            cursor.execute("DELETE FROM audit_log")
            
            cursor.execute("UPDATE question_threads SET status = 'upcoming' WHERE session_id = ?", (session_id,))
            cursor.execute("UPDATE question_threads SET status = 'current', sort_order = 1 WHERE session_id = ? AND thread_id = 'thr_101'", (session_id,))
            
            conn.commit()
        return self.get_session(session_id)

    def clear_thread_answers(self, session_id: str, thread_id: str) -> Session:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM answer_entries WHERE thread_id = ?", (thread_id,))
            conn.commit()
        return self.get_session(session_id)

    def accept_question_thread(self, session_id: str, thread_id: str) -> Session:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            now_iso = datetime.now(timezone.utc).isoformat()

            # Retrieve existing answer entries for this thread to baseline & translate
            cursor.execute(
                "SELECT id, seq, e4b_transcript, gemma12b_output, local_language_json FROM answer_entries WHERE thread_id = ?",
                (thread_id,)
            )
            rows = cursor.fetchall()

            for r in rows:
                row_id = r["id"]
                raw_text = r["e4b_transcript"]
                refined_text = r["gemma12b_output"]

                # Lock local baseline
                local_base = LocalLanguageBaseline(
                    language_code="auto",
                    transcript=raw_text,
                    status="LOCKED"
                )

                # Generate and lock Corporate English Baseline
                corp_transcript = self.translation_service.translate_to_corporate_english(
                    local_transcript=refined_text or raw_text,
                    source_language="auto"
                )

                corp_base = CorporateEnglishBaseline(
                    language_code="en-US",
                    transcript=corp_transcript,
                    status="LOCKED",
                    editable=False,
                    translated_at=now_iso
                )

                cursor.execute(
                    """
                    UPDATE answer_entries 
                    SET local_language_json = ?, corporate_english_json = ? 
                    WHERE id = ?
                    """,
                    (local_base.model_dump_json(), corp_base.model_dump_json(), row_id)
                )

            # Determine maximum sort order among 'previous' threads to append to the last spot
            cursor.execute("SELECT COALESCE(MAX(sort_order), 0) + 1 AS max_prev FROM question_threads WHERE session_id = ? AND status = 'previous'", (session_id,))
            max_prev_order = cursor.fetchone()["max_prev"]

            # Update target thread to 'previous' and set its sort order to the last spot
            cursor.execute(
                "UPDATE question_threads SET status = 'previous', sort_order = ? WHERE session_id = ? AND thread_id = ?",
                (max_prev_order, session_id, thread_id)
            )

            # Find next upcoming thread to promote to 'current'
            cursor.execute(
                "SELECT thread_id FROM question_threads WHERE session_id = ? AND status = 'upcoming' ORDER BY sort_order ASC LIMIT 1",
                (session_id,)
            )
            next_up = cursor.fetchone()
            if next_up:
                cursor.execute(
                    "UPDATE question_threads SET status = 'current' WHERE session_id = ? AND thread_id = ?",
                    (session_id, next_up["thread_id"])
                )

            audit_payload = json.dumps({"accepted_thread": thread_id, "promoted_next": next_up["thread_id"] if next_up else None})
            cursor.execute(
                "INSERT INTO audit_log (timestamp, session_id, thread_id, action, payload) VALUES (?, ?, ?, ?, ?)",
                (now_iso, session_id, thread_id, "ACCEPT_AND_BASELINE", audit_payload)
            )

            conn.commit()
        return self.get_session(session_id)

    def get_session(self, session_id: str) -> Session:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT session_id FROM sessions WHERE session_id = ?", (session_id,))
            session_row = cursor.fetchone()
            if not session_row:
                raise ValueError(f"Session {session_id} not found.")

            cursor.execute(
                "SELECT thread_id, question_text, status, sort_order FROM question_threads WHERE session_id = ? ORDER BY sort_order ASC",
                (session_id,)
            )
            thread_rows = cursor.fetchall()
            threads = []

            for tr in thread_rows:
                thread_id = tr["thread_id"]
                cursor.execute(
                    "SELECT seq, e4b_transcript, gemma12b_output, tts_audio_path, local_language_json, corporate_english_json, recorded_at FROM answer_entries WHERE thread_id = ? ORDER BY seq ASC",
                    (thread_id,)
                )
                answer_rows = cursor.fetchall()
                answers = []
                for ar in answer_rows:
                    loc_base = LocalLanguageBaseline(**json.loads(ar["local_language_json"])) if ar["local_language_json"] else None
                    corp_base = CorporateEnglishBaseline(**json.loads(ar["corporate_english_json"])) if ar["corporate_english_json"] else None

                    answers.append(AnswerEntry(
                        seq=ar["seq"],
                        e4b_transcript=ar["e4b_transcript"],
                        gemma12b_output=ar["gemma12b_output"],
                        tts_audio_path=ar["tts_audio_path"],
                        local_language_baseline=loc_base,
                        corporate_english_baseline=corp_base,
                        recorded_at=ar["recorded_at"]
                    ))

                threads.append(QuestionThread(
                    thread_id=tr["thread_id"],
                    question_text=tr["question_text"],
                    status=tr["status"],
                    sort_order=tr["sort_order"],
                    answers=answers
                ))

            return Session(session_id=session_id, question_threads=threads)

    def add_answer(self, session_id: str, thread_id: str, e4b_transcript: str, gemma12b_output: str, local_baseline: Optional[LocalLanguageBaseline] = None) -> AnswerEntry:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            # Determine next seq number
            cursor.execute("SELECT COALESCE(MAX(seq), 0) + 1 AS next_seq FROM answer_entries WHERE thread_id = ?", (thread_id,))
            next_seq = cursor.fetchone()["next_seq"]

            recorded_at = datetime.now(timezone.utc).isoformat()
            
            loc_json = local_baseline.model_dump_json() if local_baseline else LocalLanguageBaseline(transcript=e4b_transcript, status="COMPILED").model_dump_json()

            cursor.execute(
                """
                INSERT INTO answer_entries (thread_id, seq, e4b_transcript, gemma12b_output, local_language_json, recorded_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (thread_id, next_seq, e4b_transcript, gemma12b_output, loc_json, recorded_at)
            )

            # Audit log
            audit_payload = json.dumps({
                "seq": next_seq,
                "e4b_transcript": e4b_transcript,
                "gemma12b_output": gemma12b_output,
                "recorded_at": recorded_at
            })
            cursor.execute(
                "INSERT INTO audit_log (timestamp, session_id, thread_id, action, payload) VALUES (?, ?, ?, ?, ?)",
                (recorded_at, session_id, thread_id, "ADD_ANSWER", audit_payload)
            )
            conn.commit()

            return AnswerEntry(
                seq=next_seq,
                e4b_transcript=e4b_transcript,
                gemma12b_output=gemma12b_output,
                local_language_baseline=local_baseline or LocalLanguageBaseline(transcript=e4b_transcript, status="COMPILED"),
                recorded_at=recorded_at
            )

    def consolidate_question_thread(self, session_id: str, thread_id: str, gemma_service) -> Session:
        """
        Gathers all recorded answer snippets for thread_id, consolidates them via Gemma 12B,
        and saves a new consolidated iteration entry.
        """
        session = self.get_session(session_id)
        target_thread = next((t for t in session.question_threads if t.thread_id == thread_id), None)
        if not target_thread or not target_thread.answers:
            return session

        consolidated_output = gemma_service.consolidate_appends(
            question_text=target_thread.question_text,
            answer_entries=target_thread.answers
        )

        if not consolidated_output:
            return session

        local_base = LocalLanguageBaseline(
            language_code="auto",
            transcript=consolidated_output,
            status="COMPILED"
        )

        self.add_answer(
            session_id=session_id,
            thread_id=thread_id,
            e4b_transcript=f"[Consolidated Baseline] {consolidated_output}",
            gemma12b_output=consolidated_output,
            local_baseline=local_base
        )

        return self.get_session(session_id)


