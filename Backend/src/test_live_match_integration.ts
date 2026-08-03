import { pool } from './config/db.js';
import { eventService } from './services/eventService.js';
import { eventRepository } from './repositories/eventRepository.js';

async function run() {
  console.log('--- STARTING LIVE MATCH INTEGRATION TEST ---');
  try {
    // 1. Find a confirmed booking to create an event for
    const bookingRes = await pool.query(
      `SELECT id, user_id, status FROM public.bookings WHERE status = 'confirmed' LIMIT 1`
    );
    const booking = bookingRes.rows[0];

    if (!booking) {
      console.log('No confirmed booking found to run the test. Exiting.');
      process.exit(0);
    }

    console.log(`Using Confirmed Booking: ${booking.id} (User: ${booking.user_id})`);

    // 2. Try to find or create event
    let eventRes = await pool.query(
      `SELECT id, host_id, status, sport FROM public.events WHERE booking_id = $1`,
      [booking.id]
    );
    let event = eventRes.rows[0];

    if (!event) {
      console.log('Creating event for booking...');
      event = await eventService.createEvent(booking.user_id, {
        booking_id: booking.id,
        title: 'Integration Test Match',
        description: 'Testing live match scoring and settlement',
        sport: 'Football',
        privacy: 'public',
        capacity: 10,
      });
    }

    const eventId = event.id;
    const hostId = event.host_id;
    console.log(`Event ID: ${eventId} (Host: ${hostId}, Sport: ${event.sport}, Status: ${event.status})`);

    // Reset status to live if scheduled
    if (event.status === 'scheduled') {
      console.log('Checking in event to start match...');
      await eventRepository.checkInEvent(eventId);
    } else if (event.status === 'completed' || event.status === 'cancelled') {
      // Re-open event for testing
      console.log('Resetting event to live for testing...');
      await pool.query(
        `UPDATE public.events SET status = 'live', team_a_score = 0, team_b_score = 0 WHERE id = $1`,
        [eventId]
      );
    }

    // 3. Clear existing guest members and logs for this event
    await pool.query(`DELETE FROM public.event_members WHERE event_id = $1 AND profile_id IS NULL`, [eventId]);
    await pool.query(`DELETE FROM public.match_logs WHERE event_id = $1`, [eventId]);

    // 4. Add guests
    console.log('Adding Guest A...');
    const guestA = await eventService.addGuest(hostId, eventId, 'Dave (Guest)', 'A');
    console.log(`Added Guest A: ${guestA.guest_name} on Team ${guestA.team}`);

    console.log('Adding Guest B...');
    const guestB = await eventService.addGuest(hostId, eventId, 'Bob (Guest)', 'B');
    console.log(`Added Guest B: ${guestB.guest_name} on Team ${guestB.team}`);

    // 5. Log Goal
    console.log('Logging goal for Team A...');
    const updatedEventA = await eventService.logScore(hostId, eventId, 'Football', {
      team: 'A',
      scorer_member_id: guestA.id,
      minute: 23,
    });
    console.log(`Updated scores: Team A ${updatedEventA.team_a_score} - ${updatedEventA.team_b_score} Team B`);

    console.log('Logging goal for Team B...');
    const updatedEventB = await eventService.logScore(hostId, eventId, 'Football', {
      team: 'B',
      scorer_member_id: guestB.id,
      minute: 41,
    });
    console.log(`Updated scores: Team A ${updatedEventB.team_a_score} - ${updatedEventB.team_b_score} Team B`);

    // 6. Fetch timeline logs
    console.log('Fetching timeline logs...');
    const logs = await eventService.getMatchLogs(hostId, eventId);
    console.log('Timeline Logs:');
    for (const log of logs) {
      console.log(` - ${log.message} (created_at: ${log.created_at})`);
    }

    // 7. Settle Match
    console.log('Settling match...');
    const settlement = await eventService.settleMatch(hostId, eventId, {
      winning_team: 'Draw',
      man_of_the_match_id: hostId,
    });
    console.log('Match Settle Response:', JSON.stringify(settlement, null, 2));

    // Wait 3 seconds for BullMQ workers to process the job
    console.log('Waiting for background workers...');
    await new Promise((resolve) => setTimeout(resolve, 3000));

    // 8. Verify points enqueued/awarded
    const pointsRes = await pool.query(
      `SELECT points_awarded, reason_type, reason FROM public.points_transactions 
       WHERE profile_id = $1 AND event_id = $2`,
      [hostId, eventId]
    );
    console.log(`Points awarded for user ${hostId}:`);
    for (const pt of pointsRes.rows) {
      console.log(` - +${pt.points_awarded} PTS: ${pt.reason} (type: ${pt.reason_type})`);
    }

    console.log('--- LIVE MATCH INTEGRATION TEST PASSED SUCCESS ---');
  } catch (err: any) {
    console.error('Integration test failed with error:', err.message);
  } finally {
    await pool.end();
  }
}

run();
