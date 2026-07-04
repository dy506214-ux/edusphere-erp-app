async function main() {
  const baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';

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

  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  };

  // Test combination 1: Capitalized keys
  const payload1 = {
    topic: 'Cell Division',
    subject: 'Biology',
    className: 'Grade 8',
    referenceText: 'Mitosis is a process of cell duplication, or reproduction, during which one cell gives rise to two genetically identical daughter cells.',
    questionTypes: {
      'MCQS': 2,
      'ONE WORD': 1,
      'SHORT': 1,
      'LONG': 1
    },
    complexity: 'Medium'
  };

  console.log('Testing payload 1...');
  const res1 = await fetch(`${baseUrl}/ai/generate-smart-assignment`, {
    method: 'POST',
    headers,
    body: JSON.stringify(payload1)
  });
  console.log('Payload 1 response:', await res1.json());

  // Test combination 2: Plural keys
  const payload2 = {
    topic: 'Cell Division',
    subject: 'Biology',
    className: 'Grade 8',
    referenceText: 'Mitosis is a process of cell duplication, or reproduction, during which one cell gives rise to two genetically identical daughter cells.',
    questionTypes: {
      'mcqs': 2,
      'one_word': 1,
      'short': 1,
      'long': 1
    },
    complexity: 'Medium'
  };

  console.log('Testing payload 2...');
  const res2 = await fetch(`${baseUrl}/ai/generate-smart-assignment`, {
    method: 'POST',
    headers,
    body: JSON.stringify(payload2)
  });
  console.log('Payload 2 response:', await res2.json());
}

main().catch(console.error);
