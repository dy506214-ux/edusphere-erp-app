const axios = require('axios');

async function main() {
  const baseUrl = 'https://edusphere-erp-latest-xffb.onrender.com/api/v1';
  try {
    console.log('Logging in to live API...');
    const loginRes = await axios.post(`${baseUrl}/auth/login`, {
      email: 'teacher1@edusphere.com',
      password: 'Password@123'
    });
    const token = loginRes.data.token;
    console.log('Login successful, token:', token.substring(0, 15) + '...');
    
    // Test case 2: sectionId is null
    console.log('Sending bulk attendance request with sectionId as null...');
    const bulkRes = await axios.post(`${baseUrl}/attendance/bulk`, {
      date: '2026-07-01',
      classId: '61a64068-bb6e-49f5-bce6-65c66f31baa8',
      sectionId: null,
      attendanceData: [
        { studentId: '29e8d09a-3567-4404-8df1-841ded87993c', status: 'PRESENT' }
      ]
    }, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('Bulk Response Status:', bulkRes.status);
    console.log('Bulk Response Body:', JSON.stringify(bulkRes.data, null, 2));

  } catch (err) {
    console.error('API request failed:', err.response ? err.response.data : err.message);
  }
}

main();
