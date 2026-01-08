
import { GoogleGenAI } from "@google/genai";

// Always initialize with named parameter and direct process.env.API_KEY
const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });

export const getAIResponse = async (userMessage: string, history: { role: string, text: string }[]) => {
  try {
    // Transform history into parts as expected by the Gemini API
    const contents = history.map(h => ({
      role: h.role,
      parts: [{ text: h.text }]
    }));
    
    // Append the latest user message
    contents.push({ role: 'user', parts: [{ text: userMessage }] });

    const response = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: contents,
      config: {
        systemInstruction: "You are the AI Guardian, a calm and professional assistant for caregivers. Your goal is to provide concise, medically-aware (but not diagnostic) advice, safety tips, and emotional support. If a user mentions an emergency, always suggest triggering the SOS or calling emergency services.",
        temperature: 0.7,
      },
    });

    // Directly access the .text property from GenerateContentResponse
    return response.text;
  } catch (error) {
    console.error("Gemini AI error:", error);
    return "I'm having trouble connecting right now. Please check the patient's status manually.";
  }
};
