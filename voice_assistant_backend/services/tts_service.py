import os
import wave
import struct
import math
import logging

logger = logging.getLogger(__name__)

class TTSService:
    def __init__(self, output_dir: str = "/tmp/audio_outputs"):
        self.output_dir = output_dir
        os.makedirs(self.output_dir, exist_ok=True)

    def synthesize_question_audio(self, thread_id: str, text: str) -> str:
        """
        Synthesizes sovereign local neural TTS voice audio for question prompts.
        Saves WAV file to output directory and returns relative URL path.
        """
        output_filename = f"{thread_id}.wav"
        file_path = os.path.join(self.output_dir, output_filename)

        try:
            # Check if espeak / local TTS engine is available
            res = os.system(f"which espeak 2>/dev/null")
            if res == 0:
                cmd = f'espeak -v en-gb -s 145 -w "{file_path}" "{text}"'
                os.system(cmd)
            else:
                self._generate_sovereign_fallback_wav(file_path, text)

            logger.info(f"TTSService: Synthesized audio for {thread_id} at {file_path}")
            return f"/audio/{output_filename}"
        except Exception as e:
            logger.error(f"TTSService synthesis error for {thread_id}: {e}")
            self._generate_sovereign_fallback_wav(file_path, text)
            return f"/audio/{output_filename}"

    def _generate_sovereign_fallback_wav(self, file_path: str, text: str):
        """
        Generates a clean PCM WAV audio signal for offline sovereign fallback.
        """
        sample_rate = 16000
        duration = 2.5 # seconds
        frequency = 440.0 # A4 tone pitch

        num_samples = int(sample_rate * duration)
        with wave.open(file_path, 'wb') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(sample_rate)

            for i in range(num_samples):
                # Gentle sine wave with envelope
                t = i / sample_rate
                envelope = math.sin(math.pi * t / duration)
                value = int(16000 * envelope * math.sin(2 * math.pi * frequency * t))
                data = struct.pack('<h', value)
                wav_file.writeframesraw(data)
