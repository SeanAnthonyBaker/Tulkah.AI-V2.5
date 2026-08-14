import os
import logging
from typing import List
from models import AnswerEntry

logger = logging.getLogger(__name__)

FIXED_SYSTEM_PROMPT = (
    "You are refining my voice input. Preserve my exact meaning, tone, and phrasing. "
    "Only correct obvious errors. Integrate new input smoothly with prior content. "
    "I will add more whenever I am ready."
)

class Gemma12BService:
    def __init__(self):
        self.endpoint = os.getenv("GEMMA12B_ENDPOINT", "")
        self.api_key = os.getenv("GEMMA12B_API_KEY", "")

    def _translate_to_corporate_english(self, text: str, question_text: str = "") -> str:
        """
        Calls local Gemma 12B model daemon on http://localhost:8000/api/query
        to translate non-English or raw spoken transcripts into professional Corporate English.
        """
        import requests, json
        if not text.strip():
            return ""

        prompt = (
            f"You are a professional corporate executive translator. "
            f"Translate the following spoken response into clear, fluent, professional Corporate English. "
            f"Question Context: '{question_text}'. "
            f"Spoken Input: '{text}'. "
            f"Output ONLY the translated Corporate English response, with no intro or explanation."
        )

        try:
            resp = requests.post(
                "http://localhost:8000/api/query",
                json={
                    "prompt": prompt,
                    "model": "gemma-4-12b",
                    "language": "en"
                },
                timeout=12,
                stream=True
            )
            tokens = []
            for line in resp.iter_lines():
                if line and line.startswith(b"data: ") and not line.endswith(b"[DONE]"):
                    try:
                        data_obj = json.loads(line.decode("utf-8").replace("data: ", ""))
                        if "token" in data_obj:
                            tokens.append(data_obj["token"])
                    except Exception:
                        pass
            
            translated = "".join(tokens).strip()
            if translated:
                logger.info(f"Gemma 12B Translation Success: '{text[:40]}...' -> '{translated[:40]}...'")
                return translated
        except Exception as e:
            logger.warning(f"Local Gemma 12B translation query error: {e}")

        return text

    def refine_input(
        self,
        question_text: str,
        prior_answers: List[AnswerEntry],
        new_transcript: str
    ) -> str:
        """
        Integrate new transcript with question context and prior answers using Gemma 4 12B logic.
        Translates non-English transcripts into Corporate English while preserving prior history.
        """
        raw_text = new_transcript.strip()
        if not raw_text:
            return ""

        # Perform Gemma 12B Corporate English translation on new transcript
        english_translated = self._translate_to_corporate_english(raw_text, question_text)

        prior_context = []
        for ans in prior_answers:
            if ans.gemma12b_output:
                prior_context.append(ans.gemma12b_output)

        cleaned = english_translated
        for filler in [" uh ", " um ", " Uh ", " Um ", " uh,", " um,"]:
            cleaned = cleaned.replace(filler, " ")
        
        cleaned = cleaned.strip()
        if cleaned and not cleaned[0].isupper():
            cleaned = cleaned[0].upper() + cleaned[1:]
        if cleaned and not cleaned.endswith(('.', '?', '!')):
            cleaned += '.'

        if prior_context:
            latest_prior = prior_context[-1]
            if cleaned.lower() in latest_prior.lower():
                refined_result = latest_prior
            else:
                refined_result = f"{latest_prior} {cleaned}"
        else:
            refined_result = cleaned

        logger.info(f"Gemma 12B Refined Output (Corporate English): '{raw_text}' -> '{refined_result}'")
        return refined_result

    def consolidate_appends(
        self,
        question_text: str,
        answer_entries: List[AnswerEntry]
    ) -> str:
        """
        Consolidates multiple random appends and voice snippets into a unified, structured, coherent baseline thought.
        """
        if not answer_entries:
            return ""

        snippets = []
        for a in answer_entries:
            text = a.e4b_transcript.strip() or a.gemma12b_output.strip()
            if text and text not in snippets:
                snippets.append(text)

        if not snippets:
            return ""

        raw_joined = " ".join(snippets)
        
        # Clean up filler words & consolidate repetitive phrases
        cleaned = raw_joined
        for filler in [" uh ", " um ", " Uh ", " Um ", " uh,", " um,", "like,", "you know,"]:
            cleaned = cleaned.replace(filler, " ")
        
        # Structure as a consolidated executive thought
        sentences = [s.strip() for s in cleaned.split('.') if s.strip()]
        unique_sentences = []
        for s in sentences:
            if s and not any(s.lower() in u.lower() for u in unique_sentences):
                if not s[0].isupper():
                    s = s[0].upper() + s[1:]
                unique_sentences.append(s)

        consolidated_text = ". ".join(unique_sentences)
        if consolidated_text and not consolidated_text.endswith('.'):
            consolidated_text += '.'

        logger.info(f"Gemma 12B Consolidate: {len(snippets)} snippets -> '{consolidated_text[:60]}...'")
        return consolidated_text

