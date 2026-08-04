import { pool } from '../config/db.js';

export interface EventRow {
  id: string;
  booking_id: string;
  host_id: string;
  turf_id: string;
  title: string;
  description: string | null;
  sport: 'Football' | 'Cricket' | 'Badminton' | 'Basketball' | 'Tennis';
  privacy: 'public' | 'private';
  capacity: number;
  status: 'scheduled' | 'live' | 'completed' | 'cancelled';
  invite_token: string | null;
  qr_check_in_code: string | null;
  starts_at: string;
  ends_at: string;
  checked_in_at: string | null;
  created_at: string;
  turf_name?: string; // joined field helper
  // New scoring fields:
  team_a_score?: number;
  team_b_score?: number;
  team_a_wickets?: number;
  team_b_wickets?: number;
  team_a_balls?: number;
  team_b_balls?: number;
  current_batting?: 'team_a' | 'team_b' | 'unassigned';
  striker_id?: string | null;
  non_striker_id?: string | null;
  current_bowler_id?: string | null;
  toss_winner_team?: 'team_a' | 'team_b' | 'unassigned' | null;
  toss_decision?: 'bat' | 'bowl' | null;
  max_overs?: number;
}

export interface EventMemberRow {
  id: string;
  event_id: string;
  profile_id: string | null;
  guest_name: string | null;
  team: 'unassigned' | 'team_a' | 'team_b';
  is_official: boolean;
  added_by: string;
  joined_at: string;
  username?: string;    // joined profile fields
  full_name?: string;
  avatar_url?: string | null;
  // Cricket stats
  batting_runs?: number;
  balls_faced?: number;
  is_out?: boolean;
  bowler_runs?: number;
  bowler_wickets?: number;
  bowler_balls?: number;
  bowler_wides?: number;
  bowler_noballs?: number;
  bowler_dots?: number;
  bowler_fours?: number;
  bowler_sixes?: number;
}

interface CursorParts {
  starts_at: string;
  id: string;
}

function decodeCursor(cursor: string): CursorParts | null {
  try {
    const decoded = Buffer.from(cursor, 'base64').toString('utf-8');
    return JSON.parse(decoded);
  } catch {
    return null;
  }
}

function encodeCursor(starts_at: string, id: string): string {
  return Buffer.from(JSON.stringify({ starts_at, id })).toString('base64');
}

export const eventRepository = {
  /**
   * Create an event calling the security definer function in a transaction.
   */
  async createEvent(
    userId: string,
    data: {
      booking_id: string;
      title: string;
      description?: string;
      sport: string;
      privacy: string;
      capacity: number;
    }
  ): Promise<EventRow> {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(`SELECT set_config('request.jwt.claim.sub', $1, true)`, [userId]);
      const result = await client.query(
        `SELECT * FROM public.create_event($1, $2, $3, $4::sport_type, $5::event_privacy, $6::smallint)`,
        [
          data.booking_id,
          data.title,
          data.description ?? null,
          data.sport,
          data.privacy,
          data.capacity,
        ]
      );
      await client.query('COMMIT');
      return result.rows[0] as EventRow;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  /**
   * Join an event calling the join_event security definer function.
   */
  async joinEvent(userId: string, eventId: string): Promise<EventMemberRow> {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(`SELECT set_config('request.jwt.claim.sub', $1, true)`, [userId]);
      const result = await client.query(`SELECT * FROM public.join_event($1)`, [eventId]);
      await client.query('COMMIT');
      return result.rows[0] as EventMemberRow;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  /**
   * Add a guest player to the roster.
   */
  async addGuest(userId: string, eventId: string, guestName: string, team: string = 'unassigned'): Promise<EventMemberRow> {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(`SELECT set_config('request.jwt.claim.sub', $1, true)`, [userId]);
      const result = await client.query(
        `SELECT * FROM public.add_guest($1, $2, $3::public.roster_team)`,
        [eventId, guestName, team]
      );
      await client.query('COMMIT');
      return result.rows[0] as EventMemberRow;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  /**
   * Assign a roster member to a team.
   */
  async assignTeam(
    userId: string,
    eventId: string,
    memberId: string,
    team: 'unassigned' | 'team_a' | 'team_b'
  ): Promise<EventMemberRow> {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(`SELECT set_config('request.jwt.claim.sub', $1, true)`, [userId]);
      const result = await client.query(
        `SELECT * FROM public.assign_team($1, $2, $3::roster_team)`,
        [eventId, memberId, team]
      );
      await client.query('COMMIT');
      return result.rows[0] as EventMemberRow;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  /**
   * Resolve an invite token to retrieve a private event details.
   */
  async resolveInvite(token: string): Promise<EventRow | null> {
    const result = await pool.query(`SELECT * FROM public.resolve_invite($1)`, [token]);
    return result.rows[0] ?? null;
  },

  /**
   * Find event by ID, including turf details and scores.
   */
  async findById(id: string): Promise<EventRow | null> {
    const result = await pool.query(
      `SELECT e.id, e.booking_id, e.host_id, e.turf_id, e.title, e.description, e.sport, e.privacy, e.capacity,
              e.status, e.invite_token, e.qr_check_in_code, e.starts_at::text, e.ends_at::text, e.checked_in_at::text, e.created_at::text,
              e.team_a_score, e.team_b_score, e.team_a_wickets, e.team_b_wickets, e.team_a_balls, e.team_b_balls, e.current_batting,
              e.striker_id, e.non_striker_id, e.current_bowler_id, e.toss_winner_team, e.toss_decision, e.max_overs,
              t.name as turf_name
       FROM public.events e
       JOIN public.turfs t ON t.id = e.turf_id
       WHERE e.id = $1`,
      [id]
    );
    return result.rows[0] ?? null;
  },

  /**
   * List public and accessible private events with cursor pagination.
   */
  async listEvents(
    params: {
      sport?: string;
      status: string;
      cursor?: string;
      limit: number;
    },
    userId?: string
  ): Promise<{ data: EventRow[]; next_cursor: string | null }> {
    const values: unknown[] = [params.status, params.limit + 1];
    let queryIndex = 3;

    let sportClause = '';
    if (params.sport) {
      sportClause = `AND e.sport = $${queryIndex}::sport_type`;
      values.push(params.sport);
      queryIndex++;
    }

    let authClause = `AND e.privacy = 'public'`;
    if (userId) {
      authClause = `AND (
        e.privacy = 'public'
        OR e.host_id = $${queryIndex}::uuid
        OR EXISTS (
          SELECT 1 FROM public.follows f
          WHERE f.follower_id = $${queryIndex}::uuid AND f.following_id = e.host_id
        )
        OR EXISTS (
          SELECT 1 FROM public.event_members m
          WHERE m.event_id = e.id AND m.profile_id = $${queryIndex}::uuid
        )
      )`;
      values.push(userId);
      queryIndex++;
    }

    let cursorClause = '';
    if (params.cursor) {
      const parts = decodeCursor(params.cursor);
      if (parts) {
        cursorClause = `AND (e.starts_at, e.id) > ($${queryIndex}::timestamptz, $${queryIndex + 1}::uuid)`;
        values.push(parts.starts_at, parts.id);
        queryIndex += 2;
      }
    }

    let timeClause = '';
    if (params.status === 'scheduled') {
      timeClause = `AND e.ends_at > (NOW() AT TIME ZONE 'Asia/Kolkata')`;
    }

    const sql = `
      SELECT e.id, e.booking_id, e.host_id, e.turf_id, e.title, e.description, e.sport, e.privacy, e.capacity,
             e.status, e.invite_token, e.qr_check_in_code, e.starts_at::text, e.ends_at::text, e.checked_in_at::text, e.created_at::text,
             e.team_a_score, e.team_b_score, e.team_a_wickets, e.team_b_wickets, e.team_a_balls, e.team_b_balls, e.current_batting,
             e.striker_id, e.non_striker_id, e.current_bowler_id, e.toss_winner_team, e.toss_decision, e.max_overs,
             t.name as turf_name
      FROM public.events e
      JOIN public.turfs t ON t.id = e.turf_id
      WHERE e.status = $1
        ${timeClause}
        ${sportClause}
        ${authClause}
        ${cursorClause}
      ORDER BY e.starts_at ASC, e.id ASC
      LIMIT $2
    `;

    const result = await pool.query(sql, values);
    const rows = result.rows as EventRow[];

    const hasMore = rows.length > params.limit;
    const data = hasMore ? rows.slice(0, params.limit) : rows;

    const finalNextCursor = hasMore && data.length > 0
      ? encodeCursor(data[data.length - 1].starts_at, data[data.length - 1].id)
      : null;

    return {
      data,
      next_cursor: finalNextCursor,
    };
  },

  /**
   * Get members of an event.
   */
  async getEventMembers(eventId: string): Promise<EventMemberRow[]> {
    const result = await pool.query(
      `SELECT em.id, em.event_id, em.profile_id, em.guest_name, em.team, em.is_official, em.added_by, em.joined_at::text,
              p.username, p.full_name, p.avatar_url,
              -- Cricket statistics
              COALESCE((SELECT SUM(runs) FROM public.match_logs WHERE scorer_member_id = em.id AND log_type = 'runs'), 0)::integer as batting_runs,
              COALESCE((SELECT COUNT(*) FROM public.match_logs WHERE scorer_member_id = em.id AND log_type IN ('runs', 'dot')), 0)::integer as balls_faced,
              EXISTS (SELECT 1 FROM public.match_logs WHERE scorer_member_id = em.id AND log_type = 'wicket') as is_out,
              COALESCE((SELECT SUM(runs) FROM public.match_logs WHERE bowler_member_id = em.id), 0)::integer as bowler_runs,
              COALESCE((SELECT COUNT(*) FROM public.match_logs WHERE bowler_member_id = em.id AND log_type = 'wicket' AND dismissal_type <> 'run_out'), 0)::integer as bowler_wickets,
              COALESCE((SELECT COUNT(*) FROM public.match_logs WHERE bowler_member_id = em.id AND log_type IN ('runs', 'dot', 'wicket') AND extra_type IS NULL), 0)::integer as bowler_balls,
              COALESCE((SELECT COUNT(*) FROM public.match_logs WHERE bowler_member_id = em.id AND extra_type = 'wide'), 0)::integer as bowler_wides,
              COALESCE((SELECT COUNT(*) FROM public.match_logs WHERE bowler_member_id = em.id AND extra_type = 'no_ball'), 0)::integer as bowler_noballs,
              COALESCE((SELECT COUNT(*) FROM public.match_logs WHERE bowler_member_id = em.id AND runs = 0 AND log_type = 'dot'), 0)::integer as bowler_dots,
              COALESCE((SELECT COUNT(*) FROM public.match_logs WHERE bowler_member_id = em.id AND runs = 4 AND log_type = 'runs'), 0)::integer as bowler_fours,
              COALESCE((SELECT COUNT(*) FROM public.match_logs WHERE bowler_member_id = em.id AND runs = 6 AND log_type = 'runs'), 0)::integer as bowler_sixes
       FROM public.event_members em
       LEFT JOIN public.profiles p ON p.id = em.profile_id
       WHERE em.event_id = $1
       ORDER BY em.joined_at ASC`,
      [eventId]
    );
    return result.rows as EventMemberRow[];
  },

  /**
   * Update event title, description, or capacity.
   */
  async updateEvent(
    id: string,
    data: { title?: string; description?: string; capacity?: number }
  ): Promise<EventRow> {
    const fields: string[] = [];
    const values: unknown[] = [];
    let index = 1;

    if (data.title !== undefined) {
      fields.push(`title = $${index}`);
      values.push(data.title);
      index++;
    }
    if (data.description !== undefined) {
      fields.push(`description = $${index}`);
      values.push(data.description);
      index++;
    }
    if (data.capacity !== undefined) {
      fields.push(`capacity = $${index}`);
      values.push(data.capacity);
      index++;
    }

    values.push(id);
    const sql = `
      UPDATE public.events
      SET ${fields.join(', ')}
      WHERE id = $${index}
      RETURNING id, booking_id, host_id, turf_id, title, description, sport, privacy, capacity,
                status, invite_token, qr_check_in_code, starts_at::text, ends_at::text, checked_in_at::text, created_at::text,
                team_a_score, team_b_score, team_a_wickets, team_b_wickets, team_a_balls, team_b_balls, current_batting
    `;

    const result = await pool.query(sql, values);
    return result.rows[0];
  },

  /**
   * Remove a member or guest from the roster.
   */
  async deleteMember(eventId: string, memberId: string): Promise<boolean> {
    const result = await pool.query(
      `DELETE FROM public.event_members WHERE event_id = $1 AND id = $2`,
      [eventId, memberId]
    );
    return (result.rowCount ?? 0) > 0;
  },

  /**
   * Cancel an event.
   */
  async cancelEvent(id: string): Promise<EventRow> {
    const result = await pool.query(
      `UPDATE public.events
       SET status = 'cancelled'
       WHERE id = $1
       RETURNING id, booking_id, host_id, turf_id, title, description, sport, privacy, capacity,
                 status, invite_token, qr_check_in_code, starts_at::text, ends_at::text, checked_in_at::text, created_at::text,
                 team_a_score, team_b_score, team_a_wickets, team_b_wickets, team_a_balls, team_b_balls, current_batting`,
      [id]
    );
    return result.rows[0];
  },

  /**
   * Check in to start the event (updates status to live).
   */
  async checkInEvent(id: string): Promise<EventRow> {
    const result = await pool.query(
      `UPDATE public.events
       SET status = 'live', checked_in_at = NOW()
       WHERE id = $1
       RETURNING id, booking_id, host_id, turf_id, title, description, sport, privacy, capacity,
                 status, invite_token, qr_check_in_code, starts_at::text, ends_at::text, checked_in_at::text, created_at::text,
                 team_a_score, team_b_score, team_a_wickets, team_b_wickets, team_a_balls, team_b_balls, current_batting`,
      [id]
    );
    return result.rows[0];
  },

  /**
   * Cron helper: Complete live events whose ends_at is in the past.
   */
  async autoCompleteLiveEvents(): Promise<number> {
    const result = await pool.query(
      `UPDATE public.events
       SET status = 'completed'
       WHERE status = 'live' AND ends_at < (NOW() AT TIME ZONE 'Asia/Kolkata')`
    );
    return result.rowCount ?? 0;
  },

  /**
   * Cron helper: Complete scheduled events whose ends_at is past 1 hour and never got checked in.
   */
  async autoCompleteScheduledFallback(): Promise<number> {
    const result = await pool.query(
      `UPDATE public.events
       SET status = 'completed'
       WHERE status = 'scheduled' AND ends_at < (NOW() AT TIME ZONE 'Asia/Kolkata') - INTERVAL '1 hour'`
    );
    return result.rowCount ?? 0;
  },

  /**
   * Insert a match timeline log.
   */
  async insertMatchLog(params: {
    eventId: string;
    team: string;
    scorerMemberId?: string | null;
    bowlerMemberId?: string | null;
    minute?: number;
    overNumber?: number;
    logType: string;
    runs?: number;
    extraType?: string;
    dismissalType?: string;
    message: string;
  }): Promise<any> {
    const { eventId, team, scorerMemberId, bowlerMemberId, minute, overNumber, logType, runs = 0, extraType, dismissalType, message } = params;
    const result = await pool.query(
      `INSERT INTO public.match_logs (
        event_id, team, scorer_member_id, bowler_member_id, minute, over_number, log_type, runs, extra_type, dismissal_type, message
      ) VALUES ($1, $2::public.roster_team, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [
        eventId,
        team,
        scorerMemberId ?? null,
        bowlerMemberId ?? null,
        minute ?? null,
        overNumber ?? null,
        logType,
        runs,
        extraType ?? null,
        dismissalType ?? null,
        message,
      ]
    );
    return result.rows[0];
  },

  /**
   * Update match score and details on public.events.
   */
  async updateMatchScore(
    id: string,
    updates: {
      team_a_score?: number;
      team_b_score?: number;
      team_a_wickets?: number;
      team_b_wickets?: number;
      team_a_balls?: number;
      team_b_balls?: number;
      current_batting?: string;
      striker_id?: string | null;
      non_striker_id?: string | null;
      current_bowler_id?: string | null;
      toss_winner_team?: string | null;
      toss_decision?: string | null;
      max_overs?: number;
    }
  ): Promise<EventRow> {
    const fields: string[] = [];
    const values: unknown[] = [];
    let index = 1;

    for (const [key, val] of Object.entries(updates)) {
      if (key === 'current_batting' || key === 'toss_winner_team') {
        fields.push(`${key} = $${index}::public.roster_team`);
      } else {
        fields.push(`${key} = $${index}`);
      }
      values.push(val);
      index++;
    }

    values.push(id);
    const sql = `
      UPDATE public.events
      SET ${fields.join(', ')}
      WHERE id = $${index}
      RETURNING id, booking_id, host_id, turf_id, title, description, sport, privacy, capacity,
                status, invite_token, qr_check_in_code, starts_at::text, ends_at::text, checked_in_at::text, created_at::text,
                team_a_score, team_b_score, team_a_wickets, team_b_wickets, team_a_balls, team_b_balls, current_batting,
                striker_id, non_striker_id, current_bowler_id, toss_winner_team, toss_decision, max_overs
    `;

    const result = await pool.query(sql, values);
    return result.rows[0];
  },

  /**
   * Get all match timeline logs for an event.
   */
  async getMatchLogs(eventId: string): Promise<any[]> {
    const result = await pool.query(
      `SELECT ml.*, em.guest_name, p.username, p.full_name
       FROM public.match_logs ml
       LEFT JOIN public.event_members em ON em.id = ml.scorer_member_id
       LEFT JOIN public.profiles p ON p.id = em.profile_id
       WHERE ml.event_id = $1
       ORDER BY ml.created_at ASC`,
      [eventId]
    );
    return result.rows;
  },

  /**
   * Insert a match result row.
   */
  async insertMatchResult(params: {
    eventId: string;
    winningTeam: string;
    manOfTheMatchId?: string;
    submittedBy: string;
  }): Promise<void> {
    const { eventId, winningTeam, manOfTheMatchId, submittedBy } = params;
    await pool.query(
      `INSERT INTO public.match_results (
        event_id, winning_team, man_of_the_match_id, submitted_by
      ) VALUES ($1, $2::public.winning_team_type, $3, $4)
       ON CONFLICT (event_id) DO UPDATE SET
         winning_team = EXCLUDED.winning_team,
         man_of_the_match_id = EXCLUDED.man_of_the_match_id,
         submitted_by = EXCLUDED.submitted_by`,
      [eventId, winningTeam, manOfTheMatchId ?? null, submittedBy]
    );
  }
};
