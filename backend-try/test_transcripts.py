"""
AURA Backend - Transcript Test Runner
Run this while the server is running: uvicorn app.main:app --reload --port 8000
Usage: python test_transcripts.py
"""

import requests
import json

BASE_URL = "http://localhost:8000"

# ──────────────────────────────────────────────
# Add as many test transcripts as you want here
# ──────────────────────────────────────────────
TEST_TRANSCRIPTS = {

    "Team Meeting": """
        Good morning everyone. Welcome to our Q1 product planning meeting. The mobile app
        redesign is about 70 percent complete. Ahmed has been leading the frontend work and
        the new UI components are looking great. However, we are behind on the API integration.
        Sarah, I need you to prioritize the authentication module this week. The deadline for
        the beta release is April 1st and we cannot slip on that. Moving on to the analytics
        dashboard, we have decided to switch from Chart.js to D3 for better customization.
        Mike, can you start the migration by Wednesday? Also, regarding the budget, we got
        approval for two additional developer hires. HR will start posting the job listings
        next Monday. One more thing, the client demo is scheduled for March 28th. Everyone
        needs to have their features demo-ready by March 25th.
    """,

    "Technical Discussion": """
        Alright team, lets talk about the database performance issues. Our PostgreSQL queries
        on the orders table are taking over 3 seconds during peak hours. I ran EXPLAIN ANALYZE
        and the main bottleneck is the join between orders and inventory. We need to add a
        composite index on order_id and product_id. Tom, can you handle the index migration
        by Friday? Also, we should consider switching to read replicas for the reporting
        dashboard. Lisa, please research AWS RDS read replica pricing and give us a cost
        estimate by next Tuesday. One important decision: we are going to implement connection
        pooling using PgBouncer. DevOps will set up PgBouncer on the staging server first.
        Raj, can you tune the Datadog alert thresholds and reduce false positives?
    """,

    "Lecture / Educational": """
        Today we are going to cover the fundamentals of machine learning. Machine learning
        is a subset of artificial intelligence that focuses on building systems that learn
        from data. There are three main types: supervised learning, unsupervised learning,
        and reinforcement learning. In supervised learning, you train a model on labeled data.
        For example, you might feed it thousands of images labeled as cat or dog and it learns
        to classify new images. Popular algorithms include linear regression, decision trees,
        and neural networks. Unsupervised learning works with unlabeled data and tries to
        find hidden patterns. Clustering and dimensionality reduction are common techniques.
        For your assignment, read chapters 3 and 4 of the textbook and complete the exercises
        on page 87. The quiz on supervised learning is scheduled for next Thursday.
    """,

    "Customer Support Call": """
        Hi, thank you for calling TechCorp support, my name is Jessica. How can I help you
        today? The customer reported that their account has been locked after three failed
        login attempts. I verified the customer identity using their email and last four
        digits of their phone number. The account was locked due to our security policy.
        I have now reset the password and sent a recovery link to their email address. I also
        enabled two-factor authentication as requested by the customer. The customer should
        receive the email within 5 minutes. I advised them to check their spam folder if
        they do not see it. The ticket has been marked as resolved. Follow up in 24 hours
        if the customer reports any further issues.
    """,

    "Startup Pitch": """
        Good afternoon investors. I am Alex Chen, founder and CEO of GreenRoute. We are
        building an AI-powered logistics platform that reduces carbon emissions in last-mile
        delivery by 35 percent. The global last-mile delivery market is worth 108 billion
        dollars and growing at 15 percent annually. Our platform uses machine learning to
        optimize delivery routes in real-time, consolidating packages and reducing empty
        truck miles. We currently have 12 paying customers including two Fortune 500
        companies. Our monthly recurring revenue is 85 thousand dollars with 20 percent
        month-over-month growth. We are raising 3 million dollars in seed funding to expand
        our engineering team and enter three new markets by Q4. Sarah Kim, our CTO, will
        handle the technical scaling. We project reaching profitability by Q2 next year.
    """,

}


def test_health():
    """Check if the server is running."""
    try:
        r = requests.get(f"{BASE_URL}/health")
        if r.status_code == 200:
            print("Server is healthy!\n")
            return True
        else:
            print(f"Server returned status {r.status_code}")
            return False
    except requests.ConnectionError:
        print("ERROR: Cannot connect to server!")
        print("Make sure the server is running:")
        print("  uvicorn app.main:app --reload --port 8000")
        return False


def test_transcript(name, transcript):
    """Send a transcript to the API and display results."""
    print(f"\n{'='*60}")
    print(f"  TEST: {name}")
    print(f"{'='*60}")

    r = requests.post(
        f"{BASE_URL}/api/analyze",
        json={"transcript": transcript.strip()},
    )

    if r.status_code != 200:
        print(f"  FAILED with status {r.status_code}: {r.text}")
        return

    data = r.json()

    print(f"\n  SUMMARY:")
    print(f"  {data['summary']}")

    print(f"\n  KEY POINTS ({len(data['key_points'])}):")
    for i, point in enumerate(data['key_points'], 1):
        print(f"    {i}. {point}")

    print(f"\n  ACTION ITEMS ({len(data['action_items'])}):")
    if data['action_items']:
        for item in data['action_items']:
            print(f"    -> {item}")
    else:
        print(f"    (none detected)")

    print(f"\n  TOPICS: {', '.join(data['topics'])}")
    print(f"  KEYWORDS: {', '.join(data['keywords'][:7])}")
    print()


if __name__ == "__main__":
    print("AURA Backend - Transcript Test Runner")
    print("-" * 40)

    if not test_health():
        exit(1)

    for name, transcript in TEST_TRANSCRIPTS.items():
        test_transcript(name, transcript)

    print("=" * 60)
    print(f"  All {len(TEST_TRANSCRIPTS)} tests completed!")
    print("=" * 60)
