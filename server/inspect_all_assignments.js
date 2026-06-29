const axios = require('axios');

async function main() {
  const loginUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1/auth/login';
  
  try {
    const loginRes = await axios.post(loginUrl, {
      email: 'student1@edusphere.com',
      password: 'Password@123'
    });
    
    const token = loginRes.data.token;
    
    console.log('\nFetching student assignments...');
    const resAssignments = await axios.get('https://edusphere-erp-frontend.onrender.com/api/v1/assignments/student', {
      headers: { Authorization: `Bearer ${token}` }
    });
    const assignments = resAssignments.data.assignments || [];
    console.log('Assignments count:', assignments.length);
    console.log(JSON.stringify(assignments, null, 2));
  } catch (error) {
    console.error('Error:', error.response?.status, error.response?.data || error.message);
  }
}

main();
