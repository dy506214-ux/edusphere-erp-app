const https = require('https');
const fs = require('fs');
const path = require('path');

const postData = JSON.stringify({
  email: 'student2@edusphere.com',
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
      const userId = loginRes.user.id;
      console.log('Login successful! Token acquired. User ID:', userId);

      // Create a dummy image file
      const dummyFilePath = path.join(__dirname, 'dummy.png');
      fs.writeFileSync(dummyFilePath, 'dummy image binary content');

      // Prepare Multipart payload
      const boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW';
      const filename = 'dummy.png';
      const fileField = 'avatar';

      let multipartBody = '';
      multipartBody += `--${boundary}\r\n`;
      multipartBody += `Content-Disposition: form-data; name="${fileField}"; filename="${filename}"\r\n`;
      multipartBody += 'Content-Type: image/png\r\n\r\n';
      
      const fileData = fs.readFileSync(dummyFilePath);
      const footer = `\r\n--${boundary}--\r\n`;

      const totalLength = Buffer.byteLength(multipartBody) + fileData.length + Buffer.byteLength(footer);

      const uploadOptions = {
        hostname: 'edusphere-erp-frontend.onrender.com',
        path: `/api/v1/users/${userId}/avatar`,
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': `multipart/form-data; boundary=${boundary}`,
          'Content-Length': totalLength
        }
      };

      const uploadReq = https.request(uploadOptions, (uploadRes) => {
        let uBody = '';
        uploadRes.on('data', (d) => { uBody += d; });
        uploadRes.on('end', () => {
          console.log('Upload status:', uploadRes.statusCode);
          console.log('Upload response:', uBody);
          
          // Clean up dummy file
          try { fs.unlinkSync(dummyFilePath); } catch(_) {}
        });
      });

      uploadReq.on('error', (err) => {
        console.error('Upload request error:', err);
      });

      uploadReq.write(multipartBody);
      uploadReq.write(fileData);
      uploadReq.write(footer);
      uploadReq.end();

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
