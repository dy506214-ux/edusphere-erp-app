async function main() {
  const baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';

  console.log('1. Logging in...');
  const loginRes = await fetch(`${baseUrl}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: 'teacher1@edusphere.com',
      password: 'Password@123',
    })
  });
  
  const loginData = await loginRes.json();
  const token = loginData.token;
  console.log('Token obtained.');

  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  };

  console.log('2. Fetching teacher assignments...');
  const res = await fetch(`${baseUrl}/assignments/teacher`, { headers });
  console.log('Response Status:', res.status);
  const data = await res.json();
  console.log('Recent assignments count:', data.assignments?.length);
  if (data.assignments && data.assignments.length > 0) {
    console.log('Most recent assignment title:', data.assignments[0].title);
    console.log('Most recent assignment description snippet:', data.assignments[0].description?.substring(0, 100));
    console.log('Most recent assignment filePath:', data.assignments[0].filePath);
  }
}

main().catch(console.error);
