const axios = require('axios');

async function main() {
  const baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';
  try {
    console.log('Logging in to live API...');
    const loginRes = await axios.post(`${baseUrl}/auth/login`, {
      email: 'teacher1@edusphere.com',
      password: 'Password@123'
    });
    const token = loginRes.data.token;
    console.log('Login successful, token:', token.substring(0, 15) + '...');
    
    console.log('Fetching slot details for 8c0df2d0-1da3-47d1-8c14-f00dbe2c09f4...');
    const slotRes = await axios.get(`${baseUrl}/attendance/slots/8c0df2d0-1da3-47d1-8c14-f00dbe2c09f4`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    
    console.log('Slot data payload from live server:');
    console.log(JSON.stringify(slotRes.data, null, 2));
    
  } catch (err) {
    console.error('API request failed:', err.response ? err.response.data : err.message);
  }
}

main();
