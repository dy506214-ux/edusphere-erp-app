const https = require('https');

const key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE";

const url = "https://bstevdkjqjzaglayicdg.supabase.co/rest/v1/AcademicYear?id=eq.3b6fa212-5ef4-4db9-a3fa-3f12c4a61573";

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
    console.log("=== Academic Year ID Check ===");
    console.log(data);
  });
}).on('error', (err) => {
  console.error("Error:", err);
});
