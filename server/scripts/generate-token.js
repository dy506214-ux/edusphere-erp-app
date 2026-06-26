const jwt = require('jsonwebtoken');
require('dotenv').config();

const secret = process.env.JWT_SECRET || 'your-super-secret-jwt-key-min-32-characters-long-change-in-production';

const payload = {
    id: 'test-admin-id',
    role: 'SUPER_ADMIN',
    email: 'admin@edusphere.com'
};

const token = jwt.sign(payload, secret, { expiresIn: '1h' });
console.log('--- Generated Test Token ---');
console.log(token);
console.log('----------------------------');
