const https = require('https');

const key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE";

const url = "https://bstevdkjqjzaglayicdg.supabase.co/rest/v1/Student?select=id,admissionNumber,rollNumber,academicYearId,currentClassId,userId&or=(admissionNumber.eq.ADM-2024017,admissionNumber.eq.ADM240063)";

const options = {
  headers: {
    "apikey": key,
    "Authorization": `Bearer ${key}`
  }
};

https.get(url, options, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    console.log("=== Student Admission Check ===");
    try {
      const parsed = JSON.parse(data);
      console.log(JSON.stringify(parsed, null, 2));
    } catch(e) {
      console.log(data);
    }
  });
}).on('error', (err) => {
  console.error("Error:", err);
});
