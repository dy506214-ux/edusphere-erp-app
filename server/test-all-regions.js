const { Client } = require('pg');

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
const projectRef = 'xernedkpgdrvjokokdoa';

async function testRegions() {
  console.log('--- Testing Direct Connection (Port 5432) ---');
  const directUri = `postgresql://postgres:${password}@db.${projectRef}.supabase.co:5432/postgres`;
  const client = new Client({ connectionString: directUri, connectionTimeoutMillis: 5000 });
  try {
    await client.connect();
    console.log('🎉 SUCCESS! Direct connection succeeded!');
    await client.end();
    return;
  } catch (err) {
    console.log(`Direct connection failed: ${err.message}`);
  }

  console.log('\n--- Testing Pooled Connections (Port 6543) ---');
  for (const region of regions) {
    const host = `aws-0-${region}.pooler.supabase.com`;
    const user = `postgres.${projectRef}`;
    const uri = `postgresql://${user}:${password}@${host}:6543/postgres`;
    console.log(`Testing pooled connection on ${region}...`);
    const pooledClient = new Client({ connectionString: uri, connectionTimeoutMillis: 5000 });
    try {
      await pooledClient.connect();
      console.log(`🎉 SUCCESS! Connected to pooled ${region}!`);
      await pooledClient.end();
      return;
    } catch (err) {
      console.log(`  Failed: ${err.message.substring(0, 100)}`);
    }
  }
}

testRegions();
