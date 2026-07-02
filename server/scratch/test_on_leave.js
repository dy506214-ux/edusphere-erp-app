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
    
    // Submit with status ON_LEAVE
    console.log('Submitting slot attendance with status ON_LEAVE...');
    const submitRes = await axios.post(`${baseUrl}/attendance/slots/${slotId}/submit`, {
      attendanceData: [
        { entityId: '29e8d09a-3567-4404-8df1-841ded87993c', status: 'ON_LEAVE' }
      ]
    }, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('Response Status:', submitRes.status);
    console.log('Response Body:', JSON.stringify(submitRes.data, null, 2));

  } catch (err) {
    console.error('API request failed:', err.response ? err.response.data : err.message);
  }
}

main();
