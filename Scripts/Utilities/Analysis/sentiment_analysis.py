# Scripts/Utilities/Analysis/sentiment_analysis.py

from textblob import TextBlob

def analyze_sentiment(text: str):
    blob = TextBlob(text)
    return blob.sentiment.polarity, blob.sentiment.subjectivity

if __name__ == "__main__":
    sample_text = "The market is showing signs of improvement."
    polarity, subjectivity = analyze_sentiment(sample_text)
    print(f"Polarity: {polarity}, Subjectivity: {subjectivity}")
