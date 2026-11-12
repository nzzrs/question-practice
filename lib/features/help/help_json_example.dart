/// Importable example shown on the Help page and copied from it.
///
/// It demonstrates two topics, topic and practice descriptions, a
/// single-answer question with `subtopic` and `sourceId`, a multi-answer
/// question with `correctIndexes`, and one explanation per alternative.
const helpJsonExample = '''
{
  "formatVersion": 1,
  "topics": [
    {
      "name": "Cloud",
      "description": "Core services and when to use them.",
      "priority": 1,
      "practices": [
        {
          "name": "Compute",
          "description": "Choosing a runtime.",
          "questions": [
            {
              "sourceId": "101",
              "prompt": "Which service runs a container image without a cluster you manage?",
              "subtopic": "Serverless",
              "alternatives": ["Compute Engine", "Cloud Run", "Cloud SQL"],
              "correctIndex": 1,
              "explanation": "Cloud Run runs containers on managed infrastructure.",
              "alternativeExplanations": [
                "Compute Engine gives you a virtual machine to manage.",
                "Correct. Cloud Run manages the cluster and scaling.",
                "Cloud SQL is a managed relational database."
              ]
            },
            {
              "sourceId": "102",
              "prompt": "Which are managed compute services?",
              "subtopic": "Serverless",
              "alternatives": ["Cloud Run", "Compute Engine", "Cloud Functions"],
              "correctIndexes": [0, 2],
              "explanation": "Cloud Run and Cloud Functions run code without a cluster you manage.",
              "alternativeExplanations": [
                "Correct. Cloud Run runs containers on managed infrastructure.",
                "Compute Engine gives you a virtual machine to manage.",
                "Correct. Cloud Functions runs event-driven code."
              ]
            }
          ]
        }
      ]
    },
    {
      "name": "Networking",
      "description": "Transport-layer basics.",
      "priority": 2,
      "practices": [
        {
          "name": "TCP",
          "description": "Reliable delivery.",
          "questions": [
            {
              "sourceId": "201",
              "prompt": "Which protocol delivers a reliable, ordered byte stream?",
              "subtopic": "Transport",
              "alternatives": ["UDP", "TCP", "ICMP"],
              "correctIndex": 1,
              "explanation": "TCP acknowledges segments and retransmits lost data.",
              "alternativeExplanations": [
                "UDP does not guarantee delivery or order.",
                "Correct. TCP delivers an ordered stream.",
                "ICMP carries control messages such as ping."
              ]
            }
          ]
        }
      ]
    }
  ]
}
''';
