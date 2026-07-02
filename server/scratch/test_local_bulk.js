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
    console.log('Login successful.');
    
    console.log('Fetching all slots for 2026-07-01...');
    const slotsRes = await axios.get(`${baseUrl}/attendance/slots`, {
      params: { date: '2026-07-01' },
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('Slots response:');
    console.log(JSON.stringify(slotsRes.data, null, 2));

  } catch (err) {
    console.log('API request failed:', err.response ? err.response.data : err.message);
  }
}

main();
