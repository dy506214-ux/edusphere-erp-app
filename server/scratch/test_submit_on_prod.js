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
    
    const slotId = '8c0df2d0-1da3-47d1-8c14-f00dbe2c09f4';
    console.log(`Fetching slot details for ${slotId}...`);
    const slotRes = await axios.get(`${baseUrl}/attendance/slots/${slotId}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    
    const entities = slotRes.data.data.entities;
    console.log(`Found ${entities.length} entities. Preparing submission payload...`);
    
    const attendanceData = entities.map(e => ({
      entityId: e.id,
      status: 'PRESENT'
    }));
    
    console.log('Submitting attendance slot...');
    const submitRes = await axios.post(`${baseUrl}/attendance/slots/${slotId}/submit`, {
      attendanceData
    }, {
      headers: { Authorization: `Bearer ${token}` }
    });
    
    console.log('Submission Response:');
    console.log(JSON.stringify(submitRes.data, null, 2));
    
  } catch (err) {
    console.error('API request failed:', err.response ? err.response.data : err.message);
  }
}

main();
