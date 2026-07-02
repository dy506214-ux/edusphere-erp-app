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

    console.log('Fetching classes...');
    const classesRes = await axios.get(`${baseUrl}/academic/classes`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('Classes Response:', JSON.stringify(classesRes.data, null, 2));

    console.log('Fetching sections...');
    const sectionsRes = await axios.get(`${baseUrl}/academic/sections`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('Sections Response:', JSON.stringify(sectionsRes.data, null, 2));

  } catch (err) {
    console.error('Error:', err.response ? err.response.data : err.message);
  }
}

main();
