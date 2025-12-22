import { GoogleGenAI, HarmCategory, HarmBlockThreshold } from "@google/genai";

const API_KEY = process.env.API_KEY || '';

class GeminiService {
  private ai: GoogleGenAI | null = null;
  private chatSession: any = null;

  constructor() {
    if (API_KEY) {
      this.ai = new GoogleGenAI({ apiKey: API_KEY });
    } else {
      console.warn("Gemini API Key is missing. AI features will be disabled.");
    }
  }

  async startChat(history: { role: string; parts: { text: string }[] }[] = []) {
    if (!this.ai) return null;

    try {
      this.chatSession = this.ai.chats.create({
        model: 'gemini-2.5-flash',
        config: {
            systemInstruction: "You are Guardian Angel, a compassionate, patient, and reassuring AI companion for an elderly user. Keep your responses short, warm, and easy to read. Do not use complex medical jargon. Your goal is to provide peace of mind. If the user expresses physical pain or emergency symptoms, calmly suggest they tap the red Emergency button or contact their caregiver. Do not diagnose.",
            temperature: 0.7,
        },
        history: history.map(h => ({
            role: h.role === 'user' ? 'user' : 'model',
            parts: h.parts
        })),
      });
      return this.chatSession;
    } catch (error) {
      console.error("Failed to start Gemini chat:", error);
      return null;
    }
  }

  async sendMessageStream(message: string) {
    if (!this.chatSession) {
      // Re-initialize if session is lost or never started
      await this.startChat();
      if (!this.chatSession) {
          throw new Error("AI Service unavailable");
      }
    }

    try {
      return await this.chatSession.sendMessageStream({ message });
    } catch (error) {
      console.error("Error sending message to Gemini:", error);
      throw error;
    }
  }
}

export const geminiService = new GeminiService();