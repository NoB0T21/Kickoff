import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const { Pool } = pg;
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:54322/postgres',
});

async function run() {
  try {
    const eventRes = await pool.query(
      "SELECT id, host_id, title FROM public.events WHERE status = 'scheduled' LIMIT 1"
    );
    if (eventRes.rows.length === 0) {
      console.log("No scheduled events found.");
      return;
    }
    const event = eventRes.rows[0];
    console.log(`Testing with Event: "${event.title}" (${event.id})`);

    const userRes = await pool.query(
      "SELECT id, email FROM auth.users WHERE id <> $1 LIMIT 1",
      [event.host_id]
    );
    if (userRes.rows.length === 0) {
      console.log("No non-host users found.");
      return;
    }
    const testUser = userRes.rows[0];
    console.log(`Simulating leave for user: ${testUser.email} (${testUser.id})`);

    const { eventService } = await import('./src/services/eventService.js');
    
    try {
      await eventService.leaveEvent(testUser.id, event.id);
      console.log("Success! User has left the event.");
    } catch (e) {
      console.log("Leave call failed with error:");
      console.error(e);
    }
  } catch (err) {
    console.error("Test runner crashed:", err);
  } finally {
    await pool.end();
  }
}

run();
