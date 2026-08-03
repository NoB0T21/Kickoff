import { supabaseAdmin } from './src/config/supabase.js';

async function run() {
  try {
    console.log("Running bookings select query...");
    const { data, error } = await supabaseAdmin
      .from('bookings')
      .select('*, turfs(*), events(id, status)')
      .limit(5);

    if (error) {
      console.error("PostgREST Error:", error);
    } else {
      console.log("Query succeeded! Data count:", data.length);
      if (data.length > 0) {
        console.log("First row details:", JSON.stringify(data[0], null, 2));
      }
    }
  } catch (err) {
    console.error("Script crashed:", err);
  }
}

run();
