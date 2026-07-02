const axios = require('axios');

async function main() {
  const baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';
  try {
    console.log('Logging in...');
    const loginRes = await axios.post(`${baseUrl}/auth/login`, {
      email: 'teacher1@edusphere.com',
      password: 'Password@123'
    });
    const token = loginRes.data.token;
    console.log('Login successful.');
    
    const slotId = '8c0df2d0-1da3-47d1-8c14-f00dbe2c09f4';
    
    // First submit
    console.log('Submitting slot attendance (first time)...');
    const res1 = await axios.post(`${baseUrl}/attendance/slots/${slotId}/submit`, {
      attendanceData: [
        { entityId: '29e8d09a-3567-4404-8df1-841ded87993c', status: 'PRESENT' }
      ]
    }, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('Submission 1 status:', res1.status);
    console.log('Submission 1 body:', res1.data);
    
    // Second submit
    console.log('Submitting slot attendance (second time)...');
    const res2 = await axios.post(`${baseUrl}/attendance/slots/${slotId}/submit`, {
      attendanceData: [
        { entityId: '29e8d09a-3567-4404-8df1-841ded87993c', status: 'PRESENT' }
      ]
    }, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('Submission 2 status:', res2.status);
    console.log('Submission 2 body:', res2.data);

  } catch (err) {
    console.error('API request failed:', err.response ? err.response.data : err.message);
  }
}

main();
