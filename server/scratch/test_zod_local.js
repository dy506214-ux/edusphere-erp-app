const { PrismaClient } = require('@prisma/client');
require('dotenv').config({ path: 'c:/edusphere/edusphere/server/.env' });

const { bulkMarkAttendance } = require('../src/controllers/attendanceController');

async function test() {
  const req = {
    body: {
      date: '2026-07-01',
      students: [
        { studentId: 'e3ec066a-5cb8-4f56-80ba-1fb15df520d3', status: 'PRESENT' }
      ]
    },
    user: {
      userId: 'dc3f0bab-36ba-4ec0-a606-d934f8555831'
    }
  };

  const res = {
    status: function(code) {
      console.log('res.status called with:', code);
      return this;
    },
    json: function(data) {
      console.log('res.json called with:', data);
      return this;
    }
  };

  try {
    console.log('Running controller bulkMarkAttendance...');
    await bulkMarkAttendance(req, res);
  } catch (err) {
    console.error('Controller threw error:', err);
  }
}

test();
