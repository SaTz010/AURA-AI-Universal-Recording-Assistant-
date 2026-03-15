import re

import spacy
from rake_nltk import Rake
from sklearn.feature_extraction.text import TfidfVectorizer
from sumy.nlp.stemmers import Stemmer
from sumy.nlp.tokenizers import Tokenizer
from sumy.parsers.plaintext import PlaintextParser
from sumy.summarizers.lsa import LsaSummarizer

from app.schemas.transcript import AnalysisResponse

nlp = spacy.load("en_core_web_sm")

# Words that are NOT valid person names in action items
NON_PERSON_WORDS = {
    "i", "we", "they", "it", "you", "he", "she", "this", "that",
    "there", "here", "what", "which", "who", "any", "all", "every",
    "everyone", "everything", "anything", "someone", "something",
    "blockers", "issues", "tasks", "problems", "updates", "changes",
}

# Patterns that indicate action items in meeting transcripts
ACTION_PATTERNS = [
    r"(?:I need|I want)\s+(\w+)\s+to\s+(.+?)(?:\.|$)",
    r"(\w+),?\s+(?:can you|could you|please|will you)\s+(.+?)(?:\.|$|\?)",
    r"(\w+)\s+(?:should|must|needs? to|has to)\s+(.+?)(?:\.|$)",
    r"(\w+)\s+is\s+(?:responsible for|taking over|leading|handling)\s+(.+?)(?:\.|$)",
]


def _extract_summary(text: str, sentence_count: int = 3) -> str:
    """Extract a summary using LSA (Latent Semantic Analysis)."""
    parser = PlaintextParser.from_string(text, Tokenizer("english"))
    stemmer = Stemmer("english")
    summarizer = LsaSummarizer(stemmer)

    summary_sentences = summarizer(parser.document, sentence_count)
    summary = " ".join(str(s) for s in summary_sentences)

    return summary if summary else text[:500]


def _extract_key_points(text: str) -> list[str]:
    """Extract key points using spaCy sentence analysis."""
    doc = nlp(text)
    scored_sentences = []

    for sent in doc.sents:
        score = 0
        sent_text = sent.text.strip()

        # Sentences with named entities are more important
        score += len([ent for ent in sent.ents]) * 2

        # Sentences with numbers/dates carry factual weight
        score += len([t for t in sent if t.like_num or t.ent_type_ in ("DATE", "TIME", "MONEY", "PERCENT")]) * 1.5

        # Longer sentences tend to carry more information
        word_count = len([t for t in sent if not t.is_punct and not t.is_space])
        if word_count > 5:
            score += 1

        # Boost sentences with decision/outcome language
        decision_words = {"decided", "approved", "confirmed", "agreed", "deadline", "schedule", "launch", "release", "complete", "priority"}
        if any(token.lemma_.lower() in decision_words for token in sent):
            score += 3

        if score > 0:
            scored_sentences.append((sent_text, score))

    scored_sentences.sort(key=lambda x: x[1], reverse=True)
    return [s[0] for s in scored_sentences[:7]]


def _extract_action_items(text: str) -> list[str]:
    """Detect action items using regex patterns and spaCy NER."""
    action_items = []

    # Build a map of person names from spaCy NER for better resolution
    doc = nlp(text)
    person_entities = [ent.text for ent in doc.ents if ent.label_ == "PERSON"]

    for pattern in ACTION_PATTERNS:
        matches = re.finditer(pattern, text, re.IGNORECASE)
        for match in matches:
            person = match.group(1).strip()
            task = match.group(2).strip()

            # Skip non-person subjects
            if person.lower() in NON_PERSON_WORDS:
                # Try to find a nearby person name from the same sentence
                sentence_start = text.rfind(".", 0, match.start()) + 1
                sentence_text = text[sentence_start:match.start()]
                found_person = None
                for name in person_entities:
                    if name in sentence_text:
                        found_person = name
                        break
                if found_person:
                    person = found_person
                else:
                    continue

            task = re.sub(r"\s+", " ", task).strip()
            if len(task) > 10:
                action_items.append(f"{person}: {task}")

    # Deduplicate while preserving order
    seen = set()
    unique = []
    for item in action_items:
        normalized = item.lower()
        if normalized not in seen:
            seen.add(normalized)
            unique.append(item)

    return unique


def _extract_keywords(text: str, top_n: int = 10) -> list[str]:
    """Extract keywords using RAKE algorithm."""
    rake = Rake(min_length=1, max_length=3)
    rake.extract_keywords_from_text(text)
    ranked = rake.get_ranked_phrases()
    return ranked[:top_n]


def _extract_topics(text: str, max_topics: int = 5) -> list[str]:
    """Identify topics using TF-IDF on sentence segments."""
    doc = nlp(text)
    sentences = [sent.text for sent in doc.sents if len(sent.text.strip()) > 10]

    if len(sentences) < 2:
        return _extract_keywords(text, max_topics)

    vectorizer = TfidfVectorizer(
        max_features=20,
        stop_words="english",
        ngram_range=(1, 2),
    )

    tfidf_matrix = vectorizer.fit_transform(sentences)
    feature_names = vectorizer.get_feature_names_out()

    # Sum TF-IDF scores across all sentences to find globally important terms
    scores = tfidf_matrix.sum(axis=0).A1
    top_indices = scores.argsort()[::-1][:max_topics]

    topics = [feature_names[i].title() for i in top_indices]
    return topics


async def analyze_transcript(transcript: str) -> AnalysisResponse:
    """Run the full local NLP pipeline on a transcript."""
    return AnalysisResponse(
        summary=_extract_summary(transcript),
        key_points=_extract_key_points(transcript),
        action_items=_extract_action_items(transcript),
        topics=_extract_topics(transcript),
        keywords=_extract_keywords(transcript),
    )
