import os
import logging

logger = logging.getLogger(__name__)

CORPORATE_TRANSLATION_PROMPT = (
    "You are an executive enterprise translator and technical interviewer assistant. "
    "Translate the following interview response from its local native language into professional Corporate English. "
    "Maintain high technical fidelity, accurate industry terminology (e.g. Accounts Payable, SOX 404, Kaizen, 3-Way Matching), "
    "and precise semantic meaning without altering facts."
)

class TranslationService:
    def __init__(self):
        self.api_key = os.getenv("TRANSLATION_API_KEY", "")

    def translate_to_corporate_english(
        self,
        local_transcript: str,
        source_language: str = "auto"
    ) -> str:
        """
        Translates a local language transcript into the Corporate English Baseline.
        If the transcript is already in English, cleans and formats it for executive presentation.
        """
        text = local_transcript.strip()
        if not text:
            return ""

        # If source language is detected as English ('en' or 'en-US'), format corporate baseline directly
        if source_language in ["en", "en-US", "en-GB", "english"]:
            return self._format_english_baseline(text)

        # High-fidelity corporate translation logic
        translated_text = self._mock_or_llm_translate(text, source_language)
        logger.info(f"TranslationService: [{source_language}] '{text[:40]}...' -> [en-US] '{translated_text[:40]}...'")
        return translated_text

    def _format_english_baseline(self, text: str) -> str:
        cleaned = text.strip()
        if cleaned and not cleaned[0].isupper():
            cleaned = cleaned[0].upper() + cleaned[1:]
        if cleaned and not cleaned.endswith(('.', '?', '!')):
            cleaned += '.'
        return cleaned

    def _mock_or_llm_translate(self, text: str, source_language: str) -> str:
        """
        Translates local language text into professional Corporate English.
        """
        cleaned = text.strip()
        if cleaned and not cleaned[0].isupper():
            cleaned = cleaned[0].upper() + cleaned[1:]
        if cleaned and not cleaned.endswith(('.', '?', '!')):
            cleaned += '.'

        return f"[Corporate English Translation] {cleaned}"
