import pandas as pd
import unicodedata
import re
from difflib import get_close_matches
from typing import List, Optional, Dict
from pathlib import Path
from transformers import pipeline

class NERFoodRecognizer:
    """
    Korean food recognition system using KoELECTRA NER model
    and fuzzy matching with food dictionary
    """

    def __init__(self):
        self.ner_pipeline = None
        self.food_dict: List[str] = []
        self._load_food_dictionary()
        self._initialize_ner_model()

    def _load_food_dictionary(self):
        """Load food dictionary from CSV file"""
        try:
            csv_path = Path(__file__).parent.parent / "data" / "food_dataset_full.csv"
            df = pd.read_csv(csv_path, encoding='utf-8')

            # Extract unique food names from '메뉴명' column
            if '메뉴명' in df.columns:
                self.food_dict = df['메뉴명'].dropna().unique().tolist()
                # Normalize all food names
                self.food_dict = [unicodedata.normalize('NFC', f.strip()) for f in self.food_dict]
                print(f"✓ Loaded {len(self.food_dict)} food items from dictionary")
            else:
                print("⚠ Warning: '메뉴명' column not found in CSV")
        except Exception as e:
            print(f"⚠ Warning: Could not load food dictionary: {e}")
            self.food_dict = []

    def _initialize_ner_model(self):
        """Initialize KoELECTRA NER model"""
        try:
            self.ner_pipeline = pipeline(
                "ner",
                model="monologg/koelectra-small-v3-discriminator",
                tokenizer="monologg/koelectra-small-v3-discriminator",
                aggregation_strategy="first"
            )
            print("✓ KoELECTRA NER model loaded successfully")
        except Exception as e:
            print(f"⚠ Warning: Could not load NER model: {e}")
            self.ner_pipeline = None

    def extract_food_from_text(self, text: str) -> List[str]:
        """
        Extract potential food names from text using NER

        Args:
            text: Input text in Korean

        Returns:
            List of potential food names
        """
        if not self.ner_pipeline:
            return []

        try:
            # Run NER pipeline
            entities = self.ner_pipeline(text)

            # Extract and filter food-like entities
            potential_foods = []
            for ent in entities:
                word = ent['word'].replace('##', '').strip()
                # Filter: Korean characters only, at least 2 characters
                if re.match(r'^[가-힣]+$', word) and len(word) >= 2:
                    potential_foods.append(word)

            # Remove duplicates while preserving order
            return list(dict.fromkeys(potential_foods))

        except Exception as e:
            print(f"Error in NER extraction: {e}")
            return []

    def match_food_to_dictionary(
        self,
        extracted_words: List[str],
        threshold: float = 0.6
    ) -> Optional[str]:
        """
        Match extracted words to food dictionary using fuzzy matching

        Args:
            extracted_words: List of words extracted by NER
            threshold: Similarity threshold (0.0 to 1.0)

        Returns:
            Best matching food name or None
        """
        if not self.food_dict or not extracted_words:
            return None

        best_match = None
        best_score = 0

        for word in extracted_words:
            # Normalize and clean the word
            word = unicodedata.normalize('NFC', re.sub(r'[^가-힣]', '', word.strip()))

            if not word:
                continue

            # Stage 1: Exact match
            if word in self.food_dict:
                return word

            # Stage 2: Substring match
            for food in self.food_dict:
                if word in food or food in word:
                    return food

            # Stage 3: Fuzzy match
            matches = get_close_matches(word, self.food_dict, n=1, cutoff=threshold)
            if matches:
                match = matches[0]
                # Calculate similarity score
                score = len(set(word) & set(match)) / len(set(word) | set(match))
                if score > best_score:
                    best_match = match
                    best_score = score

        return best_match if best_score >= threshold else None

    def search_foods(self, text: str, max_results: int = 5, threshold: float = 0.5) -> List[Dict[str, any]]:
        """
        텍스트에서 여러 음식 매칭 결과 반환

        Args:
            text: 입력 텍스트
            max_results: 최대 결과 수
            threshold: 최소 유사도

        Returns:
            매칭된 음식 리스트 (점수 순)
        """
        text_normalized = unicodedata.normalize('NFC', text)
        korean_words = re.findall(r'[가-힣]+', text_normalized)
        korean_words = [w for w in korean_words if len(w) >= 2]

        matches = []  # (food_name, score) 리스트

        # 전체 텍스트에서 직접 매칭
        for food in self.food_dict:
            if food in text_normalized:
                matches.append({"food_name": food, "score": 1.0})

        # 추출된 단어로 매칭
        for word in korean_words:
            # 정확히 일치
            if word in self.food_dict and not any(m["food_name"] == word for m in matches):
                matches.append({"food_name": word, "score": 0.95})

            # 부분 문자열 매칭
            for food in self.food_dict:
                if (word in food or food in word) and not any(m["food_name"] == food for m in matches):
                    score = len(word) / max(len(food), len(word))
                    matches.append({"food_name": food, "score": score * 0.8})

            # Fuzzy 매칭
            close_matches = get_close_matches(word, self.food_dict, n=10, cutoff=threshold)
            for food in close_matches:
                if not any(m["food_name"] == food for m in matches):
                    # 유사도 계산
                    score = len(set(word) & set(food)) / len(set(word) | set(food))
                    if score >= threshold:
                        matches.append({"food_name": food, "score": score * 0.6})

        # 점수 순으로 정렬하고 상위 N개 반환
        matches.sort(key=lambda x: x["score"], reverse=True)
        return matches[:max_results]

    def analyze_text(self, text: str, threshold: float = 0.6) -> Dict[str, any]:
        """
        Complete text analysis pipeline

        Args:
            text: Input text in Korean
            threshold: Similarity threshold for matching

        Returns:
            Dictionary with analysis results
        """
        # Normalize input text
        text_normalized = unicodedata.normalize('NFC', text)

        # Stage 1: Direct exact match in text
        for food in self.food_dict:
            if food in text_normalized:
                return {
                    "input_text": text,
                    "extracted_entities": [food],
                    "matched_food": food,
                    "success": True
                }

        # Stage 2: Extract Korean words from text
        korean_words = re.findall(r'[가-힣]+', text_normalized)
        korean_words = [w for w in korean_words if len(w) >= 2]

        # Stage 3: Match extracted words to dictionary
        for word in korean_words:
            # Exact match
            if word in self.food_dict:
                return {
                    "input_text": text,
                    "extracted_entities": korean_words,
                    "matched_food": word,
                    "success": True
                }

            # Substring match
            for food in self.food_dict:
                if word in food or food in word:
                    return {
                        "input_text": text,
                        "extracted_entities": korean_words,
                        "matched_food": food,
                        "success": True
                    }

        # Stage 4: Fuzzy match
        matched_food = None
        best_score = 0

        for word in korean_words:
            matches = get_close_matches(word, self.food_dict, n=1, cutoff=threshold)
            if matches:
                match = matches[0]
                score = len(set(word) & set(match)) / len(set(word) | set(match))
                if score > best_score:
                    matched_food = match
                    best_score = score

        if matched_food and best_score >= threshold:
            return {
                "input_text": text,
                "extracted_entities": korean_words,
                "matched_food": matched_food,
                "success": True
            }

        return {
            "input_text": text,
            "extracted_entities": korean_words,
            "matched_food": None,
            "success": False
        }


# Singleton instance
_recognizer_instance = None

def get_recognizer() -> NERFoodRecognizer:
    """Get or create singleton NER recognizer instance"""
    global _recognizer_instance
    if _recognizer_instance is None:
        _recognizer_instance = NERFoodRecognizer()
    return _recognizer_instance
