const https = require('https');

const postData = JSON.stringify({
  email: 'student1@edusphere.com',
  password: 'Password@123'
});

const reqOptions = {
  hostname: 'edusphere-erp-frontend.onrender.com',
  path: '/api/v1/auth/login',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': postData.length
  }
};

const req = https.request(reqOptions, (res) => {
  let body = '';
  res.on('data', (d) => { body += d; });
  res.on('end', () => {
    try {
      const loginRes = JSON.parse(body);
      if (!loginRes.success) {
        console.error('Login failed:', loginRes);
        return;
      }
      const token = loginRes.token;
      console.log('Login successful! Token acquired.');

      // Fetch profile
      const getOptions = {
        hostname: 'edusphere-erp-frontend.onrender.com',
        path: '/api/v1/students/me',
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${token}`
        }
      };

      https.get(getOptions, (profileRes) => {
        let pBody = '';
        profileRes.on('data', (d) => { pBody += d; });
        profileRes.on('end', () => {
          try {
            const profileData = JSON.parse(pBody);
            console.log('=== STUDENT1 PROFILE RESPONSE ===');
            console.log(JSON.stringify(profileData, null, 2));
          } catch(e) {
            console.error('Failed to parse profile JSON:', pBody);
          }
        });
      });

    } catch (e) {
      console.error('Failed to parse login JSON:', body);
    }
  });
});

req.on('error', (e) => {
  console.error(e);
});

req.write(postData);
req.end();
