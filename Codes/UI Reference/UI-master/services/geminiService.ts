
import { GoogleGenAI, Type } from "@google/genai";

// This service handles the AI logic for scanning receipts
// It adheres to the strict @google/genai coding guidelines

const getAIClient = () => {
  const apiKey = process.env.API_KEY;
  if (!apiKey) {
    console.warn("API_KEY not found in environment variables.");
    return null;
  }
  return new GoogleGenAI({ apiKey });
};

export const analyzeReceipt = async (base64Image: string): Promise<any> => {
  const ai = getAIClient();
  if (!ai) {
    throw new Error("API Key is missing. Please configure your API key.");
  }

  // Strip data URL prefix if present to get pure base64
  const cleanBase64 = base64Image.replace(/^data:image\/(png|jpeg|jpg|webp);base64,/, '');

  try {
    const response = await ai.models.generateContent({
      // Use the recommended model for basic text tasks/analysis
      model: 'gemini-3-flash-preview',
      contents: {
        parts: [
          {
            inlineData: {
              mimeType: 'image/jpeg',
              data: cleanBase64
            }
          },
          {
            text: "Analyze this receipt. Extract the restaurant name, date, total amount, and list of items with prices and quantities. Return as JSON."
          }
        ]
      },
      config: {
        responseMimeType: "application/json",
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            restaurantName: { type: Type.STRING },
            date: { type: Type.STRING },
            totalAmount: { type: Type.NUMBER },
            items: {
              type: Type.ARRAY,
              items: {
                type: Type.OBJECT,
                properties: {
                  name: { type: Type.STRING },
                  price: { type: Type.NUMBER },
                  quantity: { type: Type.NUMBER }
                }
              }
            }
          }
        }
      }
    });

    // Access response.text directly (property, not method)
    return response.text ? JSON.parse(response.text) : null;
  } catch (error) {
    console.error("Error analyzing receipt:", error);
    throw error;
  }
};
