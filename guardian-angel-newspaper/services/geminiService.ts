
import { GoogleGenAI, Type, Modality } from "@google/genai";
import { Article, Category } from "../types";

const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
const THEN_NEWS_API_TOKEN = 'DUZpYggJLNqcvMlNmVhTfD0Rg6DmzZ3vuRX0yevQ';
const NEWS_API_BASE = 'https://api.thenewsapi.com/v1/news/all';

// Manual implementation of decode function as required by SDK guidelines
function decode(base64: string) {
  const binaryString = atob(base64);
  const len = binaryString.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

// Manual implementation of decodeAudioData function as required by SDK guidelines
async function decodeAudioData(
  data: Uint8Array,
  ctx: AudioContext,
  sampleRate: number,
  numChannels: number,
): Promise<AudioBuffer> {
  const dataInt16 = new Int16Array(data.buffer);
  const frameCount = dataInt16.length / numChannels;
  const buffer = ctx.createBuffer(numChannels, frameCount, sampleRate);

  for (let channel = 0; channel < numChannels; channel++) {
    const channelData = buffer.getChannelData(channel);
    for (let i = 0; i < frameCount; i++) {
      channelData[i] = dataInt16[i * numChannels + channel] / 32768.0;
    }
  }
  return buffer;
}

/**
 * Fetches real news from TheNewsAPI
 */
const fetchRawNews = async (categories: string[], locale?: string, search?: string): Promise<any[]> => {
  try {
    const params = new URLSearchParams({
      api_token: THEN_NEWS_API_TOKEN,
      language: 'en',
      limit: '5',
      ...(categories.length && { categories: categories.join(',') }),
      ...(locale && { locale }),
      ...(search && { search })
    });

    const response = await fetch(`${NEWS_API_BASE}?${params.toString()}`);
    const json = await response.json();
    return json.data || [];
  } catch (err) {
    console.error("TheNewsAPI fetch failed:", err);
    return [];
  }
};

/**
 * Uses Gemini to take real news snippets and turn them into 
 * high-quality, elderly-friendly editorial pieces.
 */
const refineArticlesWithGemini = async (rawArticles: any[], targetCategory: Category): Promise<Article[]> => {
  if (rawArticles.length === 0) return [];

  const prompt = `You are a premium editor for "Guardian Angel", a newspaper for the elderly.
  I will provide you with several real news snippets. 
  Please transform each into a calm, respectful, and highly readable article.
  
  Format for each article:
  - id: (keep original)
  - title: (clear and factual)
  - summary: (exactly 2 lines)
  - content: (3-5 gentle paragraphs, expanding on the facts provided)
  - category: ${targetCategory}
  - readingTime: (e.g., "4 min read")
  
  Raw Data: ${JSON.stringify(rawArticles.map(a => ({ id: a.uuid, title: a.title, snippet: a.snippet })))}
  
  Return ONLY a valid JSON array.`;

  try {
    const response = await ai.models.generateContent({
      model: "gemini-3-flash-preview",
      contents: prompt,
      config: {
        responseMimeType: "application/json",
        responseSchema: {
          type: Type.ARRAY,
          items: {
            type: Type.OBJECT,
            properties: {
              id: { type: Type.STRING },
              title: { type: Type.STRING },
              summary: { type: Type.STRING },
              content: { type: Type.STRING },
              category: { type: Type.STRING },
              readingTime: { type: Type.STRING }
            },
            required: ["id", "title", "summary", "content", "category", "readingTime"]
          }
        }
      }
    });

    const refined: any[] = JSON.parse(response.text || '[]');
    return refined.map((item, idx) => ({
      ...item,
      date: new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'short' }),
      imageUrl: rawArticles[idx]?.image_url || `https://picsum.photos/seed/${item.id}/800/600`
    })) as Article[];
  } catch (err) {
    console.error("Gemini refinement failed:", err);
    // Fallback mapping if Gemini fails
    return rawArticles.map(a => ({
      id: a.uuid,
      title: a.title,
      summary: a.description || "Reading through the latest news...",
      content: a.snippet || a.description || "No further details available at this time.",
      category: targetCategory,
      imageUrl: a.image_url || `https://picsum.photos/seed/${a.uuid}/800/600`,
      readingTime: "3 min read",
      date: new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })
    }));
  }
};

export const generateDailyEdition = async (allowedCategories: Category[]): Promise<Article[]> => {
  try {
    // 1. Fetch Real News from TheNewsAPI in parallel
    const fetches = [
      // Pakistan specific
      fetchRawNews(['general'], 'pk').then(res => refineArticlesWithGemini(res, Category.Pakistan)),
      // Health
      fetchRawNews(['health']).then(res => refineArticlesWithGemini(res, Category.Health)),
      // Science
      fetchRawNews(['science']).then(res => refineArticlesWithGemini(res, Category.Science)),
      // Positive/Human Interest
      fetchRawNews([], undefined, 'inspiring OR heart-warming OR positive').then(res => refineArticlesWithGemini(res, Category.Positive)),
      // Faith
      fetchRawNews([], undefined, 'spiritual OR reflection OR spiritual growth').then(res => refineArticlesWithGemini(res, Category.Faith))
    ];

    const results = await Promise.all(fetches);
    const allArticles = results.flat();
    
    // Shuffle and filter by allowed categories
    return allArticles
      .filter(a => allowedCategories.includes(a.category as Category))
      .sort(() => Math.random() - 0.5);
      
  } catch (error) {
    console.error("Error generating daily edition:", error);
    return [];
  }
};

export const playArticleAudio = async (text: string) => {
  try {
    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash-preview-tts",
      contents: [{ parts: [{ text: `Read this news story warmly and clearly for a senior listener: ${text}` }] }],
      config: {
        responseModalities: [Modality.AUDIO],
        speechConfig: {
          voiceConfig: {
            prebuiltVoiceConfig: { voiceName: 'Kore' },
          },
        },
      },
    });

    const base64Audio = response.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data;
    if (base64Audio) {
      const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)({ sampleRate: 24000 });
      const audioBuffer = await decodeAudioData(
        decode(base64Audio),
        audioContext,
        24000,
        1,
      );

      const source = audioContext.createBufferSource();
      source.buffer = audioBuffer;
      source.connect(audioContext.destination);
      source.start();
      return source;
    }
  } catch (error) {
    console.error("Error generating audio:", error);
  }
  return null;
};
