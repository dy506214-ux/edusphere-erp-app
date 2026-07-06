const axios = require('axios');
const jwt = require('jsonwebtoken');

async function main() {
  const baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';
  console.log('Logging in...');
  try {
    const res = await axios.post(`${baseUrl}/auth/login`, {
      email: 'teacher1@edusphere.com',
      password: 'Password@123'
    });
    const token = res.data.token;
    console.log("Token:", token);
    const decoded = jwt.decode(token);
    console.log("Decoded:", decoded);

    console.log("Calling users/me...");
    const resMe = await axios.get(`${baseUrl}/users/me`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log("users/me success:", resMe.data);

    console.log("Calling teachers/me...");
    try {
      const resT = await axios.get(`${baseUrl}/teachers/me`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      console.log("teachers/me success:", resT.data);
    } catch (e) {
      console.log("teachers/me error status:", e.response ? e.response.status : e.message);
      console.log("teachers/me error body:", e.response ? e.response.data : '');
    }
  } catch (err) {
    console.error("Login failed:", err.message);
  }
}

main();
