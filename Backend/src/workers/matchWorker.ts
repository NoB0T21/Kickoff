import { Worker, Queue } from 'bullmq';
import { bullConnection } from '../config/redis.js';
import { pool } from '../config/db.js';
import { pointsService } from '../services/pointsService.js';

// Setup Achievements Queue for downstream triggers
export const achievementsQueue = new Queue('achievements-check', {
  connection: bullConnection,
});

// Setup Points Batch Queue
export const pointsQueue = new Queue('points-award-batch', {
  connection: bullConnection,
});

/**
 * 1. Points Award Batch Worker
 * Processes a settled match, awarding participation, win/draw, and MVP points.
 */
export const pointsWorker = new Worker(
  'points-award-batch',
  async (job) => {
    const { eventId, winningTeam, manOfTheMatchId, playerStats = [], settledAt } = job.data;
    console.log(`[PointsWorker] Processing match settlement for event ${eventId}`);

    // Fetch event details
    const eventRes = await pool.query(
      `SELECT title, sport, team_a_score, team_b_score FROM public.events WHERE id = $1`,
      [eventId]
    );
    const event = eventRes.rows[0];
    if (!event) {
      console.warn(`[PointsWorker] Event ${eventId} not found, skipping points allocation.`);
      return;
    }

    // Fetch official roster members
    const membersRes = await pool.query(
      `SELECT id, profile_id, team, is_official FROM public.event_members 
       WHERE event_id = $1 AND is_official = true AND profile_id IS NOT NULL`,
      [eventId]
    );
    const members = membersRes.rows;
    const memberProfileIds = members.map((m) => m.profile_id);

    // Calculate score contributions dynamically from match_logs database
    const contribsRes = await pool.query(
      `SELECT em.profile_id, SUM(CASE WHEN ml.log_type = 'goal' THEN 1 ELSE ml.runs END)::integer as score
       FROM public.match_logs ml
       JOIN public.event_members em ON em.id = ml.scorer_member_id
       WHERE ml.event_id = $1 AND em.profile_id IS NOT NULL
       GROUP BY em.profile_id`,
      [eventId]
    );

    const scoreMap = new Map<string, number>();
    for (const c of contribsRes.rows) {
      scoreMap.set(c.profile_id, c.score);
    }

    // Blend stats from host submitted playerStats body (e.g. goals)
    for (const p of playerStats) {
      if (p.profile_id && p.goals !== undefined) {
        const existing = scoreMap.get(p.profile_id) ?? 0;
        scoreMap.set(p.profile_id, Math.max(existing, p.goals));
      }
    }

    // Find the maximum score
    let maxScore = -1;
    for (const score of scoreMap.values()) {
      if (score > maxScore) {
        maxScore = score;
      }
    }

    // Select all profiles matching maximum score
    const motmProfileIds = new Set<string>();
    if (maxScore > 0) {
      for (const [profileId, score] of scoreMap.entries()) {
        if (score === maxScore) {
          motmProfileIds.add(profileId);
        }
      }
    }

    // Fall back to manual host selection if no score contributions exist
    if (motmProfileIds.size === 0 && manOfTheMatchId) {
      motmProfileIds.add(manOfTheMatchId);
    }

    console.log(`[PointsWorker] Identified Man of the Match profile(s): ${Array.from(motmProfileIds).join(', ')}`);

    // Write calculated MOTM/MVP back to match_results table in DB
    if (motmProfileIds.size > 0) {
      const firstMotm = Array.from(motmProfileIds)[0];
      await pool.query(
        `UPDATE public.match_results SET man_of_the_match_id = $1 WHERE event_id = $2`,
        [firstMotm, eventId]
      );
    }

    for (const member of members) {
      const profileId = member.profile_id;
      const team = member.team; // 'team_a' or 'team_b'

      // Calculate outcome points (Win: 50, Loss: 20, Draw: 30)
      let outcomePoints = 20; // Default Loss
      let outcomeReason = `Match loss: ${event.title}`;
      let outcomeType: 'match_participation' | 'match_win' | 'match_draw' = 'match_participation';

      if (winningTeam === 'Draw') {
        outcomePoints = 30;
        outcomeReason = `Match draw: ${event.title}`;
        outcomeType = 'match_draw';
      } else if (
        (winningTeam === 'A' && team === 'team_a') ||
        (winningTeam === 'B' && team === 'team_b')
      ) {
        outcomePoints = 50;
        outcomeReason = `Match win: ${event.title}`;
        outcomeType = 'match_win';
      }

      const keySuffix = settledAt ? `:${settledAt}` : '';
      const idempotencyKey = `${profileId}:${eventId}:${outcomeType}${keySuffix}`;

      try {
        await pointsService.awardPoints({
          profileId,
          eventId,
          points: outcomePoints,
          reasonType: outcomeType,
          reason: outcomeReason,
          idempotencyKey,
        });
      } catch (err: any) {
        console.error(`[PointsWorker] Error awarding outcome points to ${profileId}:`, err.message);
      }

      // C. Award MVP Points (+20) (supports multiple tied MOTMs)
      if (motmProfileIds.has(profileId)) {
        const mvpIdempotencyKey = `${profileId}:${eventId}:man_of_the_match${keySuffix}`;
        try {
          await pointsService.awardPoints({
            profileId,
            eventId,
            points: 20,
            reasonType: 'man_of_the_match',
            reason: `Man of the match: ${event.title}`,
            idempotencyKey: mvpIdempotencyKey,
          });
        } catch (err: any) {
          console.error(`[PointsWorker] Error awarding MOTM points to ${profileId}:`, err.message);
        }
      }
    }

    // Trigger downstream achievements check
    await achievementsQueue.add(
      'check-achievements',
      {
        eventId,
        sport: event.sport,
        winningTeam,
        motmProfileIds: Array.from(motmProfileIds),
        playerStats,
        teamAScore: event.team_a_score,
        teamBScore: event.team_b_score,
        memberProfileIds,
        members, // pass roster team info
      },
      {
        attempts: 5,
        backoff: {
          type: 'exponential',
          delay: 5000,
        },
      }
    );
  },
  { connection: bullConnection }
);

/**
 * Helper to unlock achievement in database and award bonus points.
 */
async function unlockAchievement(
  profileId: string,
  achievementId: string,
  achievementName: string,
  bonusPoints: number
): Promise<boolean> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Insert into profile_achievements (on conflict do nothing)
    const res = await client.query(
      `INSERT INTO public.profile_achievements (profile_id, achievement_id)
       VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [profileId, achievementId]
    );

    if ((res.rowCount ?? 0) === 0) {
      await client.query('COMMIT');
      return false; // Already unlocked previously
    }

    // 2. Award bonus points
    const idempotencyKey = `${profileId}:${achievementName}`;
    await client.query(
      `INSERT INTO public.points_transactions (
        profile_id, points_awarded, reason_type, reason, idempotency_key
      ) VALUES ($1, $2, 'achievement_unlock', $3, $4)
       ON CONFLICT DO NOTHING`,
      [
        profileId,
        bonusPoints,
        `Achievement unlocked: ${achievementName}`,
        idempotencyKey,
      ]
    );

    await client.query('COMMIT');
    console.log(`[AchievementsWorker] Successfully unlocked '${achievementName}' for profile ${profileId}`);
    return true;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * 2. Achievements Check Worker
 * Evaluates milestone rules and unlocks achievements dynamically.
 */
export const achievementsWorker = new Worker(
  'achievements-check',
  async (job) => {
    const {
      eventId,
      sport,
      winningTeam,
      motmProfileIds = [],
      playerStats = [],
      teamAScore,
      teamBScore,
      memberProfileIds = [],
      members = [],
    } = job.data;

    console.log(`[AchievementsWorker] Running milestone evaluations for event ${eventId}`);

    // Load achievements definition from DB
    const achsRes = await pool.query(`SELECT id, name, points_bonus FROM public.achievements`);
    const achievements = achsRes.rows;

    const findAch = (name: string) => achievements.find((a) => a.name === name);

    for (const profileId of memberProfileIds) {
      const rosterMember = members.find((m: any) => m.profile_id === profileId);
      const team = rosterMember?.team; // 'team_a' or 'team_b'

      // Check 1: First Kickoff (complete 1 match)
      const firstKickoff = findAch('First Kickoff');
      if (firstKickoff) {
        const countRes = await pool.query(
          `SELECT COUNT(*) FROM public.points_transactions 
           WHERE profile_id = $1 AND reason_type = 'match_participation'`,
          [profileId]
        );
        const matchCount = parseInt(countRes.rows[0].count, 10);
        if (matchCount >= 1) {
          await unlockAchievement(profileId, firstKickoff.id, firstKickoff.name, firstKickoff.points_bonus);
        }
      }

      // Check 2: Victory Circle (achieve 5 match wins)
      const victoryCircle = findAch('Victory Circle');
      if (victoryCircle) {
        const countRes = await pool.query(
          `SELECT COUNT(*) FROM public.points_transactions 
           WHERE profile_id = $1 AND reason_type = 'match_win'`,
          [profileId]
        );
        const winCount = parseInt(countRes.rows[0].count, 10);
        if (winCount >= 5) {
          await unlockAchievement(profileId, victoryCircle.id, victoryCircle.name, victoryCircle.points_bonus);
        }
      }

      // Check 3: Golden Boot (score 3 goals in a single Football match)
      if (sport === 'Football') {
        const goldenBoot = findAch('Golden Boot');
        if (goldenBoot) {
          const stats = playerStats.find((s: any) => s.profile_id === profileId);
          const goals = stats?.goals ?? 0;
          if (goals >= 3) {
            await unlockAchievement(profileId, goldenBoot.id, goldenBoot.name, goldenBoot.points_bonus);
          }
        }
      }

      // Check 4: Clean Sheet (play a match with 0 goals conceded)
      const cleanSheet = findAch('Clean Sheet');
      if (cleanSheet && team) {
        let isCleanSheet = false;
        if (sport === 'Football') {
          if (team === 'team_a' && teamBScore === 0) isCleanSheet = true;
          if (team === 'team_b' && teamAScore === 0) isCleanSheet = true;
        } else if (sport === 'Cricket') {
          if (team === 'team_a' && teamBScore === 0) isCleanSheet = true;
          if (team === 'team_b' && teamAScore === 0) isCleanSheet = true;
        }

        if (isCleanSheet) {
          await unlockAchievement(profileId, cleanSheet.id, cleanSheet.name, cleanSheet.points_bonus);
        }
      }

      // Check 5: Match MVP (voted MOTM in any event)
      if (motmProfileIds.includes(profileId)) {
        const matchMvp = findAch('Match MVP');
        if (matchMvp) {
          await unlockAchievement(profileId, matchMvp.id, matchMvp.name, matchMvp.points_bonus);
        }
      }
    }
  },
  { connection: bullConnection }
);

pointsWorker.on('failed', (job, err) => {
  console.error(`[PointsWorker] Job ${job?.id} failed with error: ${err.message}`);
});

achievementsWorker.on('failed', (job, err) => {
  console.error(`[AchievementsWorker] Job ${job?.id} failed with error: ${err.message}`);
});
