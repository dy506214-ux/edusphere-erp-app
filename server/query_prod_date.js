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
    console.log('Login successful, token resolved.');

    // Query /attendance/date
    const classId = '61a64068-bb6e-49f5-bce6-65c66f31baa8';
    const sectionId = '93e9b426-7125-4630-8d77-ade725c6708b';
    const date = '2026-07-01';

    console.log(`Querying attendance for date=${date}, classId=${classId}, sectionId=${sectionId}...`);
    const dateRes = await axios.get(`${baseUrl}/attendance/date`, {
      params: { date, classId, sectionId },
      headers: { Authorization: `Bearer ${token}` }
    });

    console.log('Response status:', dateRes.status);
    console.log('Response body:', JSON.stringify(dateRes.data, null, 2));
  } catch (err) {
    console.error('API query failed:', err.response ? err.response.data : err.message);
  }
}
main();
