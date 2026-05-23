const axios = require('axios');
require('dotenv').config();

async function checkApi() {
  const url = `https://generativelanguage.googleapis.com/v1beta/models?key=${process.env.GEMINI_API_KEY}`;
  try {
    const response = await axios.get(url);
    console.log('--- Available Models ---');
    response.data.models.forEach(m => console.log(m.name, '-', m.displayName));
  } catch (error) {
    console.error('Error:', error.response ? error.response.status : error.message);
    if (error.response && error.response.data) {
      console.error('Details:', JSON.stringify(error.response.data, null, 2));
    }
  }
}

checkApi();
