const { GoogleGenerativeAI } = require('@google/generative-ai');
require('dotenv').config();

async function listAllModels() {
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  try {
    const models = await genAI.listModels();
    console.log('--- Available Models ---');
    models.forEach(m => console.log(m.name, '-', m.displayName));
  } catch (error) {
    console.error('Error listing models:', error.message);
  }
}

listAllModels();
