const jwt = require('jsonwebtoken');

const token = process.argv[2];
if (!token) {
  console.log("No token provided");
  process.exit(1);
}

try {
  const decoded = jwt.decode(token);
  console.log("Decoded Token:", decoded);
} catch (e) {
  console.error("Error decoding:", e);
}
