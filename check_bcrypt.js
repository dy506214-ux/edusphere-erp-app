const bcrypt = require('bcryptjs');

const hash = "$2b$10$lrBi5mSKdj2oeHlVWXOMHOtrJgS2N.CKzweb2.OFnt3MkvPCvfwui";
const candidates = [
  "edusphere",
  "Admin@2024",
  "Teacher@123",
  "Student@123",
  "password",
  "admin",
  "123456",
  "Student@2024",
  "Teacher@2024"
];

for (const cand of candidates) {
  try {
    if (bcrypt.compareSync(cand, hash)) {
      console.log(`🎉 FOUND! Password is: ${cand}`);
      process.exit(0);
    }
  } catch (e) {
    console.error(e);
  }
}
console.log("No candidates matched.");
