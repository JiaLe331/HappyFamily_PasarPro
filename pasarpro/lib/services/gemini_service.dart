import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // ⚠️ Replace with your actual key
  final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: 'AIzaSyAVs8PCNK4YpcyPj9GT5hBm1ewphyRvvL0');

  Future<String?> parseLedger(String speechText) async {
    final prompt = """
    Act as a financial parser for a Malaysian hawker. 
    Convert this speech into a JSON object with keys: 'expense', 'revenue', and 'item'.
    If 'buy' or 'cost', put in expense. If 'sell' or 'untung', put in revenue.
    Speech: "$speechText"
    Return ONLY JSON.
    """;

    final response = await model.generateContent([Content.text(prompt)]);
    return response.text;
  }
}