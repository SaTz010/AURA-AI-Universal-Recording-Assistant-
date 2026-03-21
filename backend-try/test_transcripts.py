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
        Professor:
Good morning everyone. Today we’re going to begin our introduction to Neural Networks, which are one of the foundational components of modern machine learning systems.

Before we dive deep, I want to start with a simple question.

Why do we even need neural networks when we already have traditional algorithms?

Think about image recognition, speech recognition, or language translation. These tasks are extremely difficult to solve using traditional rule-based programming.

Instead of writing rules manually, neural networks learn patterns from data.

At a high level, a neural network is inspired by the human brain. In our brain we have neurons connected through synapses. In artificial neural networks we also have nodes, which we call neurons, connected through weighted connections.

These networks learn by adjusting those weights.

Student 1:
Professor, when you say weights, what exactly do you mean?

Professor:
Good question.

A weight represents the importance of a connection between two neurons.

Imagine you are trying to classify whether an email is spam or not.

Some words like "free" or "win" might have a high weight toward spam classification.

Other words like "meeting" or "schedule" might contribute more toward normal emails.

During training, the neural network adjusts these weights automatically based on data.

Professor:
Now let’s talk about the basic structure of a neural network.

A neural network typically has three main types of layers:

Input Layer

Hidden Layers

Output Layer

The input layer receives the raw data.

For example, if we’re classifying handwritten digits, the input could be pixel values from an image.

Hidden layers perform intermediate computations and extract features.

Finally, the output layer produces the prediction.

Student 2:
How many hidden layers can a neural network have?

Professor:
Technically, there is no strict limit.

However, networks with many hidden layers are called Deep Neural Networks, which is where the term deep learning comes from.

Deep learning models can have dozens or even hundreds of layers depending on the architecture.

Professor:
Now let’s briefly discuss how neural networks learn.

The learning process mainly involves two steps:

Forward Propagation

Backpropagation

In forward propagation, the input data moves through the network layer by layer until we get a prediction.

Then we compare the prediction with the actual answer.

The difference between them is called the loss or error.

Backpropagation is the process of sending that error backward through the network to adjust the weights.

This adjustment usually uses an optimization algorithm such as Gradient Descent.

Student 3:
Is gradient descent the only optimization method used?

Professor:
Not at all.

Gradient descent is the basic one, but there are many improved versions like:

Stochastic Gradient Descent (SGD)

Adam Optimizer

RMSProp

These methods help models converge faster and avoid getting stuck in poor solutions.

Professor:
Let’s consider a simple example.

Suppose we want to build a neural network that predicts house prices.

Our inputs might include:

House size

Number of bedrooms

Location

Age of the property

The network processes these features and outputs a predicted price.

If the predicted price is far from the actual price, the model adjusts its internal weights during training.

Over time, the predictions improve.

Student 4:
How much data do neural networks usually require?

Professor:
Another excellent question.

Neural networks typically require large amounts of data to perform well.

This is one reason why deep learning became practical only after the rise of big datasets and powerful GPUs.

For example, training modern image recognition models often requires millions of labeled images.

Professor:
However, there are techniques to work with smaller datasets, such as:

Data augmentation

Transfer learning

Pretrained models

These methods allow us to reuse knowledge learned from other tasks.

Student 5:
What are the main limitations of neural networks?

Professor:
Great question.

Despite their power, neural networks have several challenges:

They require large computational resources.

Training can take a long time.

They are often considered black boxes, meaning their decisions are difficult to interpret.

They can overfit if not properly regularized.

Researchers are actively working on improving model interpretability and efficiency.

Professor:
Before we wrap up, I want to summarize today’s key idea:

Neural networks are data-driven models that learn complex patterns by adjusting weights between artificial neurons.

They have become the backbone of modern AI systems including:

Speech recognition

Computer vision

Natural language processing

Autonomous vehicles

In the next lecture, we will explore activation functions and understand how neurons decide whether to activate.

Please read Chapter 3 before next class.

Any final questions?

Student:
Will we implement a neural network ourselves later?

Professor:
Yes. In two weeks we will implement a simple neural network from scratch in Python so that you understand what happens under the hood.

Alright everyone, that’s all for today. See you next lecture.
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
