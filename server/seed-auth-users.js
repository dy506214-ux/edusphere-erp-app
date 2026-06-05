require('dotenv').config();
const { Client } = require('pg');

async function seedAuthUsers() {
  console.log('🔑 Starting to seed auth.users from public.User...');
  
  const client = new Client({
    connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL
  });

  try {
    await client.connect();
    console.log('✅ Connected to PostgreSQL database');

    // 1. Fetch all users from public."User"
    const usersRes = await client.query('SELECT id, email, password, role, "firstName", "lastName" FROM public."User"');
    console.log(`Found ${usersRes.rows.length} users in public."User"`);

    let successCount = 0;

    for (const user of usersRes.rows) {
      const { id, email, password, role, firstName, lastName } = user;
      const fullName = `${firstName || ''} ${lastName || ''}`.trim();
      const lowerRole = role.toLowerCase();

      try {
        // Check if user already exists in auth.users
        const authCheck = await client.query('SELECT id FROM auth.users WHERE email = $1', [email]);
        if (authCheck.rows.length > 0) {
          console.log(`⚠️  User already exists in auth.users: ${email}`);
          continue;
        }

        // Insert into auth.users
        const userInsertQuery = `
          INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at, 
            aud, role, raw_app_meta_data, raw_user_meta_data, 
            created_at, updated_at, confirmation_token, email_change, 
            email_change_token_new, recovery_token
          ) VALUES (
            $1, '00000000-0000-0000-0000-000000000000', $2, $3, NOW(),
            'authenticated', 'authenticated', '{"provider":"email","providers":["email"]}'::jsonb, 
            $4::jsonb, NOW(), NOW(), '', '', '', ''
          )
        `;
        
        const rawUserMetadata = JSON.stringify({
          role: lowerRole,
          name: fullName
        });

        await client.query(userInsertQuery, [id, email, password, rawUserMetadata]);

        // Insert into auth.identities
        const identityInsertQuery = `
          INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, 
            last_sign_in_at, created_at, updated_at
          ) VALUES (
            $1, $1, $2::jsonb, 'email', $3, NOW(), NOW(), NOW()
          )
        `;
        
        const identityData = JSON.stringify({
          sub: id,
          email: email
        });

        await client.query(identityInsertQuery, [id, identityData, id]);

        successCount++;
      } catch (err) {
        console.error(`❌ Error seeding auth for ${email}:`, err.message);
      }
    }

    console.log(`\n🎉 Successfully seeded auth credentials for ${successCount} users!`);

  } catch (error) {
    console.error('Fatal error during auth seeding:', error);
  } finally {
    await client.end();
    console.log('✅ Database connection closed');
  }
}

seedAuthUsers();
