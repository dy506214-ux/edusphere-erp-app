const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

async function main() {
    const { data, error } = await supabase.from('CommunityPost').select('*').limit(1);
    console.log("CommunityPost check:", { data, error });
    
    const { data: d2, error: e2 } = await supabase.from('CommunityPosts').select('*').limit(1);
    console.log("CommunityPosts check:", { data: d2, error: e2 });
}
main();
