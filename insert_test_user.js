const { Client } = require('pg');
const bcrypt = require('bcryptjs');
const https = require('https');

async function testLogin() {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      email: 'testuser@edusphere.edu',
      password: 'testpassword123'
    });

    const options = {
      hostname: 'edusphere-erp-frontend.onrender.com',
      port: 443,
      path: '/api/v1/auth/login',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        resolve({
          status: res.statusCode,
          body: JSON.parse(body)
        });
      });
    });

    req.on('error', (err) => reject(err));
    req.write(data);
    req.end();
  });
}

async function main() {
  const password = "akshitsha84";
  const projectRef = "bstevdkjqjzaglayicdg";
  const host = "aws-1-ap-south-1.pooler.supabase.com";
  const dbUri = `postgresql://postgres.${projectRef}:${password}@${host}:6543/postgres`;
  
  const client = new Client({ connectionString: dbUri });
  
  try {
    await client.connect();
    console.log("Connected to database!");
    
    // 1. Delete user if exists
    await client.query('DELETE FROM public."User" WHERE email = $1', ['testuser@edusphere.edu']);
    
    // 2. Hash password
    const hashedPassword = bcrypt.hashSync('testpassword123', 10);
    console.log("Generated hash:", hashedPassword);
    
    // 3. Insert user
    const insertQuery = `
      INSERT INTO public."User" (id, email, password, "firstName", "lastName", role, "isActive", "createdAt", "updatedAt", roles)
      VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW(), $8)
    `;
    const values = [
      '99999999-9999-9999-9999-999999999999',
      'testuser@edusphere.edu',
      hashedPassword,
      'Test',
      'User',
      'ADMIN',
      true,
      ['ADMIN']
    ];
    
    await client.query(insertQuery, values);
    console.log("User inserted successfully!");
    
    // 4. Test login to Next.js API
    console.log("Testing login to Next.js API...");
    const result = await testLogin();
    if (result.status === 200) {
      console.log("✅ LOGIN SUCCESS!");
      console.log("Status:", result.status);
      console.log("Response Body:", result.body);
    } else {
      console.log("❌ LOGIN FAILED:");
      console.log("Status:", result.status);
      console.log("Response Body:", result.body);
    }
    
  } catch (err) {
    console.error("Error:", err.message);
  } finally {
    await client.end();
  }
}

main();
