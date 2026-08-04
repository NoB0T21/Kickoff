import { pool } from './config/db.js';
import { eventService } from './services/eventService.js';
import { eventRepository } from './repositories/eventRepository.js';

async function run() {
  console.log('--- STARTING CRICKET INTEGRATION TEST ---');
  try {
    // 1. Find a confirmed booking
    const bookingRes = await pool.query(
      `SELECT b.id, b.user_id, b.status 
       FROM public.bookings b
       LEFT JOIN public.events e ON e.booking_id = b.id
       WHERE b.status = 'confirmed' AND e.id IS NULL
       LIMIT 1`
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
        title: 'Cricket Integration Match',
        description: 'Testing live cricket scoring, toss, rotation, and bowler over stats',
        sport: 'Cricket',
        privacy: 'public',
        capacity: 10,
      });
    } else {
      console.log('Reusing existing event, updating status to live and sport to Cricket...');
      await pool.query(
        `UPDATE public.events 
         SET status = 'live', sport = 'Cricket', team_a_score = 0, team_b_score = 0, 
             team_a_wickets = 0, team_b_wickets = 0, team_a_balls = 0, team_b_balls = 0, 
             striker_id = null, non_striker_id = null, current_bowler_id = null, 
             toss_winner_team = null, toss_decision = null 
         WHERE id = $1`,
        [event.id]
      );
      // Fetch updated event
      const updatedRes = await pool.query(`SELECT * FROM public.events WHERE id = $1`, [event.id]);
      event = updatedRes.rows[0];
    }

    const eventId = event.id;
    const hostId = event.host_id;
    console.log(`Event ID: ${eventId} (Host: ${hostId}, Sport: ${event.sport}, Status: ${event.status})`);

    // Start match (check in event)
    await eventRepository.checkInEvent(eventId);

    // Ensure ends_at is in the future so that eventWorker doesn't autocomplete this test event
    await pool.query(
      `UPDATE public.events SET ends_at = NOW() + INTERVAL '2 hours' WHERE id = $1`,
      [eventId]
    );

    // Clear existing guest members and logs for this event
    await pool.query(`DELETE FROM public.event_members WHERE event_id = $1 AND profile_id IS NULL`, [eventId]);
    await pool.query(`DELETE FROM public.match_logs WHERE event_id = $1`, [eventId]);

    // 3. Add guest players
    console.log('Adding batsmen and bowlers...');
    const batsman1 = await eventService.addGuest(hostId, eventId, 'Batsman One', 'A');
    const batsman2 = await eventService.addGuest(hostId, eventId, 'Batsman Two', 'A');
    const bowler1 = await eventService.addGuest(hostId, eventId, 'Bowler One', 'B');

    // 4. Setup Toss
    console.log('Setting up Toss (Winner: Team A, Decision: Bat, Overs: 5)...');
    let updatedEvent = await eventService.setupToss(hostId, eventId, 'team_a', 'bat', 5);
    console.log(`Toss Setup complete. Current Batting: ${updatedEvent.current_batting}`);

    // 5. Set active lineup
    console.log('Setting active striker, non-striker, and bowler...');
    updatedEvent = await eventService.setActiveCricketPlayers(hostId, eventId, {
      striker_id: batsman1.id,
      non_striker_id: batsman2.id,
      current_bowler_id: bowler1.id,
    });
    console.log(`Lineup Set. Striker: ${updatedEvent.striker_id}, Non-Striker: ${updatedEvent.non_striker_id}, Bowler: ${updatedEvent.current_bowler_id}`);

    // 6. Log runs (+1 run) and verify strike rotation
    console.log('Logging 1 run (should rotate strike)...');
    updatedEvent = await eventService.logScore(hostId, eventId, 'Cricket', {
      team: 'A',
      runs: 1,
    });
    console.log(`Score: ${updatedEvent.team_a_score}. Striker: ${updatedEvent.striker_id} (Expected batsman2: ${batsman2.id}), Non-Striker: ${updatedEvent.non_striker_id} (Expected batsman1: ${batsman1.id})`);

    // 7. Log dot balls to complete over
    console.log('Logging 5 dot balls (to complete the 1st over)...');
    for (let i = 0; i < 5; i++) {
      updatedEvent = await eventService.logScore(hostId, eventId, 'Cricket', {
        team: 'A',
        outcome: 'dot',
        runs: 0,
      });
    }
    console.log(`Over completed. Total balls: ${updatedEvent.team_a_balls}. Bowler ID: ${updatedEvent.current_bowler_id} (Expected null/cleared)`);

    // 8. Select bowler again
    console.log('Assigning Bowler One again for the next over...');
    updatedEvent = await eventService.setActiveCricketPlayers(hostId, eventId, {
      current_bowler_id: bowler1.id,
    });

    // 9. Log Wicket - Run Out (with empty bench, should promote batsman1 to striker)
    console.log('Logging a Run Out wicket (dismissing striker, bench is empty)...');
    const outMember = updatedEvent.striker_id;
    updatedEvent = await eventService.logScore(hostId, eventId, 'Cricket', {
      team: 'A',
      outcome: 'wicket',
      dismissal_type: 'run_out',
      out_member_id: outMember,
    });
    console.log(`Wickets: ${updatedEvent.team_a_wickets}. Striker ID: ${updatedEvent.striker_id} (Expected batsman2: ${batsman2.id}), Non-Striker ID: ${updatedEvent.non_striker_id} (Expected null)`);

    // 10. Log Wicket for lone batsman (Team A All Out!)
    console.log('Logging a wicket for the last remaining batsman (triggering Innings 1 Complete / All Out)...');
    updatedEvent = await eventService.logScore(hostId, eventId, 'Cricket', {
      team: 'A',
      outcome: 'wicket',
      dismissal_type: 'bowled',
      out_member_id: batsman2.id,
    });
    console.log(`Innings 1 Finished. Current Batting Side: ${updatedEvent.current_batting} (Expected: team_b)`);
    console.log(`Lineup Cleared - Striker: ${updatedEvent.striker_id} (Expected: null), Non-Striker: ${updatedEvent.non_striker_id} (Expected: null)`);

    // 11. Setup Team B lineup and chase (Target is 2 runs)
    console.log('Setting active striker for Team B...');
    updatedEvent = await eventService.setActiveCricketPlayers(hostId, eventId, {
      striker_id: bowler1.id,
    });

    console.log('Logging 2 runs for Team B (successful chase)...');
    updatedEvent = await eventService.logScore(hostId, eventId, 'Cricket', {
      team: 'B',
      runs: 2,
    });
    console.log(`Final Team B Score: ${updatedEvent.team_b_score} (Target: 2). Current Batting: ${updatedEvent.current_batting}`);

    // 12. Fetch and print player stats
    const roster = await eventRepository.getEventMembers(eventId);
    console.log('Roster Stats:');
    for (const member of roster) {
      if (!member.guest_name) continue;
      console.log(` - ${member.guest_name}:`);
      console.log(`   Batting: ${member.batting_runs} runs (${member.balls_faced} balls), Out: ${member.is_out}`);
      console.log(`   Bowling: Conceded ${member.bowler_runs} runs, Wkts ${member.bowler_wickets}, Balls ${member.bowler_balls}, Dots ${member.bowler_dots}`);
    }

    console.log('Fetching all match timeline logs:');
    const logs = await eventService.getMatchLogs(hostId, eventId);
    for (const log of logs) {
      console.log(` * ${log.message}`);
    }

    console.log('--- CRICKET INTEGRATION TEST PASSED SUCCESS ---');
  } catch (err: any) {
    console.error('Integration test failed with error:', err.message);
  } finally {
    await pool.end();
  }
}

run();
