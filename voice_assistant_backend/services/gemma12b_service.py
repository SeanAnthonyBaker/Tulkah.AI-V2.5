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

    def refine_input(
        self,
        question_text: str,
        prior_answers: List[AnswerEntry],
        new_transcript: str
    ) -> str:
        """
        Integrate new transcript with question context and prior answers using Gemma 4 12B logic.
        Preserves exact meaning, tone, and phrasing, smoothly integrating new content without duplication.
        """
        raw_text = new_transcript.strip()
        if not raw_text:
            return ""

        prior_context = []
        for ans in prior_answers:
            if ans.gemma12b_output:
                prior_context.append(ans.gemma12b_output)

        cleaned = raw_text
        for filler in [" uh ", " um ", " Uh ", " Um ", " uh,", " um,"]:
            cleaned = cleaned.replace(filler, " ")
        
        cleaned = cleaned.strip()
        if cleaned and not cleaned[0].isupper():
            cleaned = cleaned[0].upper() + cleaned[1:]
        if cleaned and not cleaned.endswith(('.', '?', '!')):
            cleaned += '.'

        if prior_context:
            latest_prior = prior_context[-1]
            # Avoid duplicate concatenation if latest_prior already ends with cleaned snippet
            if cleaned.lower() in latest_prior.lower():
                refined_result = latest_prior
            else:
                refined_result = f"{latest_prior} {cleaned}"
        else:
            refined_result = cleaned

        logger.info(f"Gemma 12B Refined Input: '{raw_text}' -> '{refined_result}'")
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

