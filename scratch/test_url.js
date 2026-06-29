const https = require('https');

const url = "https://edusphere-erp-frontend.onrender.com/uploads/student-documents/1782722298927-829023412.png";

https.get(url, (res) => {
  console.log('Status Code:', res.statusCode);
  console.log('Headers:', res.headers);
  
  let size = 0;
  res.on('data', (chunk) => {
    size += chunk.length;
  });
  res.on('end', () => {
    console.log('Total bytes downloaded:', size);
  });
}).on('error', (err) => {
  console.error('Error:', err);
});
