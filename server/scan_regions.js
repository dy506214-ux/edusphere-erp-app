const { Client } = require('pg');
const fs = require('fs');

const regions = [
  'ap-south-1',      // Mumbai
  'ap-southeast-1',  // Singapore
  'ap-northeast-1',  // Tokyo
  'ap-northeast-2',  // Seoul
  'us-east-1',       // N. Virginia
  'us-east-2',       // Ohio
  'us-west-1',       // N. California
  'us-west-2',       // Oregon
  'eu-central-1',    // Frankfurt
  'eu-west-1',       // Ireland
  'eu-west-2',       // London
  'eu-west-3',       // Paris
  'sa-east-1',       // São Paulo
  'ca-central-1',    // Canada
  'ap-southeast-2',  // Sydney
];

const password = 'akshitsha84';
const projectRef = 'uodmjwjnhinbbvexbyvd';

async function scan() {
  let log = '';
  function writeLog(msg) {
    console.log(msg);
    log += msg + '\n';
    fs.writeFileSync('scan_output.txt', log);
  }

  writeLog('Starting scan...');
  for (const region of regions) {
    for (const prefix of ['aws-0', 'aws-1']) {
      const host = `${prefix}-${region}.pooler.supabase.com`;
      const uri = `postgresql://postgres.${projectRef}:${password}@${host}:6543/postgres`;
      writeLog(`Checking ${host}...`);
      const client = new Client({
        connectionString: uri,
        ssl: { rejectUnauthorized: false },
        connectionTimeoutMillis: 3000
      });
      try {
        await client.connect();
        writeLog(`🎉 Connected to ${host}!`);
        
        const countRes = await client.query('SELECT count(*) FROM "User"');
        writeLog(`User count in uodmjwjnhinbbvexbyvd: ${countRes.rows[0].count}`);
        
        const res = await client.query('SELECT * FROM "AttendanceSlot" WHERE id = $1', ['8c0df2d0-1da3-47d1-8c14-f00dbe2c09f4']);
        writeLog(`Slot: ${JSON.stringify(res.rows[0], null, 2)}`);
        
        if (res.rows[0]) {
          const res2 = await client.query('SELECT count(*) FROM "AttendanceRecord" WHERE "slotId" = $1', ['8c0df2d0-1da3-47d1-8c14-f00dbe2c09f4']);
          writeLog(`Records count: ${res2.rows[0].count}`);
        }
        
        await client.end();
        writeLog('Scan completed successfully.');
        return;
      } catch (err) {
        writeLog(`  Failed: ${err.message}`);
      }
    }
  }
  writeLog('❌ Failed to connect to any pooler region.');
}

scan();
