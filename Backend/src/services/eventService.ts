import { eventRepository, EventRow, EventMemberRow } from '../repositories/eventRepository.js';
import { followRepository } from '../repositories/followRepository.js';
import { pool } from '../config/db.js';
import { AppError } from '../middleware/errorHandler.js';
import { pointsQueue } from '../workers/matchWorker.js';

class EventService {
  /**
   * Create a new event.
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
      max_overs?: number;
    }
  ): Promise<EventRow> {
    try {
      // Check if event already exists
      const checkRes = await pool.query(
        `SELECT id, host_id, status, team_a_score, team_b_score FROM public.events WHERE booking_id = $1`,
        [data.booking_id]
      );
      const existing = checkRes.rows[0];
      if (existing) {
        // If the event exists and is completed/cancelled, recycle/reset it!
        if (existing.status === 'completed' || existing.status === 'cancelled') {
          console.log(`[createEvent] Recycling completed/cancelled event ${existing.id} for booking ${data.booking_id}`);
          
          let tossWinnerRecycled: string | null = null;
          if ((existing.team_a_score ?? 0) > (existing.team_b_score ?? 0)) {
            tossWinnerRecycled = 'team_a';
          } else if ((existing.team_b_score ?? 0) > (existing.team_a_score ?? 0)) {
            tossWinnerRecycled = 'team_b';
          }

          await pool.query(`DELETE FROM public.match_logs WHERE event_id = $1`, [existing.id]);
          await pool.query(
            `UPDATE public.events 
             SET status = 'live', title = $2, description = $3, sport = $4::public.sport_type, privacy = $5::public.event_privacy, capacity = $6::smallint,
                 team_a_score = 0, team_b_score = 0, team_a_wickets = 0, team_b_wickets = 0, team_a_balls = 0, team_b_balls = 0,
                 current_batting = 'team_a', striker_id = null, non_striker_id = null, current_bowler_id = null,
                 toss_winner_team = $8::public.roster_team, toss_decision = null, max_overs = $7
             WHERE id = $1`,
            [
              existing.id,
              data.title,
              data.description ?? null,
              data.sport,
              data.privacy,
              data.capacity,
              data.max_overs ?? 10,
              tossWinnerRecycled
            ]
          );
          // Return the updated event row
          const updated = await eventRepository.findById(existing.id);
          if (!updated) throw new Error('EVENT_NOT_FOUND');
          return updated;
        } else {
          throw new Error('EVENT_ALREADY_EXISTS');
        }
      }

      const event = await eventRepository.createEvent(userId, data);
      if (data.max_overs && data.sport === 'Cricket') {
        await eventRepository.updateMatchScore(event.id, { max_overs: data.max_overs });
        event.max_overs = data.max_overs;
      }
      return event;
    } catch (error: any) {
      if (error.code === '23505' && error.detail?.includes('booking_id')) {
        throw new Error('EVENT_ALREADY_EXISTS');
      }
      throw error;
    }
  }

  /**
   * List scheduled events that are public, owned by user, or owned by followed users.
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
    return eventRepository.listEvents(params, userId);
  }

  /**
   * Get event by ID and verify privacy constraints.
   */
  async getEvent(eventId: string, userId?: string): Promise<EventRow> {
    const event = await eventRepository.findById(eventId);
    if (!event) {
      throw new Error('EVENT_NOT_FOUND');
    }

    if (event.privacy === 'private') {
      if (!userId) {
        throw new Error('PRIVATE_EVENT');
      }
      if (event.host_id !== userId) {
        const members = await eventRepository.getEventMembers(eventId);
        const isMember = members.some((m) => m.profile_id === userId);
        if (!isMember) {
          const isFollowingHost = await followRepository.isFollowing(userId, event.host_id);
          if (!isFollowingHost) {
            throw new Error('PRIVATE_EVENT');
          }
        }
      }
    }

    return event;
  }

  /**
   * Resolve a private event using invite token.
   */
  async resolveInvite(token: string): Promise<EventRow> {
    const event = await eventRepository.resolveInvite(token);
    if (!event) {
      throw new Error('EVENT_NOT_FOUND'); // 404 per specs to avoid oracle
    }
    return event;
  }

  /**
   * Join a scheduled event.
   */
  async joinEvent(userId: string, eventId: string): Promise<EventMemberRow> {
    return eventRepository.joinEvent(userId, eventId);
  }

  /**
   * Leave an event (host cannot leave own event).
   */
  async leaveEvent(userId: string, eventId: string): Promise<void> {
    const event = await eventRepository.findById(eventId);
    if (!event) {
      throw new Error('EVENT_NOT_FOUND');
    }
    if (event.host_id === userId) {
      throw new Error('HOST_CANNOT_LEAVE');
    }

    const members = await eventRepository.getEventMembers(eventId);
    const member = members.find((m) => m.profile_id === userId);
    if (!member) {
      throw new Error('NOT_A_MEMBER');
    }

    await eventRepository.deleteMember(eventId, member.id);
  }

  /**
   * Add a guest player (host only).
   */
  async addGuest(userId: string, eventId: string, guestName: string, team: string = 'unassigned'): Promise<EventMemberRow> {
    // Check permission
    const event = await this.getEvent(eventId, userId);
    if (event.host_id !== userId) {
      throw new Error('FORBIDDEN');
    }
    if (event.status === 'completed') {
      throw new Error('EVENT_NOT_EDITABLE');
    }

    const teamDb = team === 'A' ? 'team_a' : (team === 'B' ? 'team_b' : team);
    return eventRepository.addGuest(userId, eventId, guestName, teamDb);
  }

  /**
   * Remove a member or guest from roster (host only).
   */
  async deleteMember(userId: string, eventId: string, memberIdToDelete: string): Promise<void> {
    const event = await eventRepository.findById(eventId);
    if (!event) {
      throw new Error('EVENT_NOT_FOUND');
    }
    if (event.host_id !== userId) {
      throw new Error('FORBIDDEN');
    }
    if (event.status === 'completed') {
      throw new Error('EVENT_NOT_EDITABLE');
    }

    const members = await eventRepository.getEventMembers(eventId);
    const member = members.find((m) => m.id === memberIdToDelete);
    if (!member) {
      throw new Error('MEMBER_NOT_FOUND');
    }

    if (member.profile_id === userId) {
      throw new Error('HOST_CANNOT_LEAVE');
    }

    await eventRepository.deleteMember(eventId, memberIdToDelete);
  }

  /**
   * Assign a member or guest to a team (host only).
   */
  async assignTeam(
    userId: string,
    eventId: string,
    memberId: string,
    team: 'unassigned' | 'team_a' | 'team_b' | 'A' | 'B'
  ): Promise<EventMemberRow> {
    // Check permission
    const event = await this.getEvent(eventId, userId);
    if (event.host_id !== userId) {
      throw new Error('FORBIDDEN');
    }
    if (event.status === 'completed') {
      throw new Error('EVENT_NOT_EDITABLE');
    }

    const teamDb = team === 'A' ? 'team_a' : (team === 'B' ? 'team_b' : team);
    return eventRepository.assignTeam(userId, eventId, memberId, teamDb as any);
  }

  /**
   * Get members of an event roster.
   */
  async getEventMembers(eventId: string, userId?: string): Promise<EventMemberRow[]> {
    // Verify privacy check first
    await this.getEvent(eventId, userId);
    return eventRepository.getEventMembers(eventId);
  }

  /**
   * Update event title, description, capacity (host only, scheduled only).
   */
  async updateEvent(
    userId: string,
    eventId: string,
    data: { title?: string; description?: string; capacity?: number }
  ): Promise<EventRow> {
    const event = await eventRepository.findById(eventId);
    if (!event) {
      throw new Error('EVENT_NOT_FOUND');
    }
    if (event.host_id !== userId) {
      throw new Error('FORBIDDEN');
    }
    if (event.status !== 'scheduled') {
      throw new Error('EVENT_NOT_EDITABLE');
    }

    if (data.capacity !== undefined) {
      // Validate bounds against database
      const boundsRes = await pool.query(
        `SELECT min_capacity, max_capacity FROM public.sport_capacity_bounds WHERE sport = $1`,
        [event.sport]
      );
      const bounds = boundsRes.rows[0];
      if (!bounds || data.capacity < bounds.min_capacity || data.capacity > bounds.max_capacity) {
        throw new Error('INVALID_CAPACITY');
      }

      // Check current roster size
      const members = await eventRepository.getEventMembers(eventId);
      if (data.capacity < members.length) {
        throw new Error('CAPACITY_BELOW_ROSTER');
      }
    }

    return eventRepository.updateEvent(eventId, data);
  }

  /**
   * Cancel an event (host only).
   */
  async cancelEvent(userId: string, eventId: string): Promise<EventRow> {
    const event = await eventRepository.findById(eventId);
    if (!event) {
      throw new Error('EVENT_NOT_FOUND');
    }
    if (event.host_id !== userId) {
      throw new Error('FORBIDDEN');
    }

    return eventRepository.cancelEvent(eventId);
  }

  /**
   * Check in to start the event (service/api authorization validated in route).
   */
  async checkIn(eventId: string, qrCode: string): Promise<EventRow> {
    const event = await eventRepository.findById(eventId);
    if (!event) {
      throw new Error('EVENT_NOT_FOUND');
    }
    if (event.qr_check_in_code !== qrCode) {
      throw new Error('INVALID_QR_CODE');
    }

    return eventRepository.checkInEvent(eventId);
  }

  /**
   * System-automated settlement when booking time ends.
   */
  async settleMatchSystem(eventId: string): Promise<void> {
    const event = await eventRepository.findById(eventId);
    if (!event || event.status !== 'live') return;

    // 1. Calculate winning team automatically based on scores
    let autoWinningTeam: 'A' | 'B' | 'Draw' = 'Draw';
    const scoreA = event.team_a_score ?? 0;
    const scoreB = event.team_b_score ?? 0;
    if (scoreA > scoreB) {
      autoWinningTeam = 'A';
    } else if (scoreB > scoreA) {
      autoWinningTeam = 'B';
    }

    // 2. Calculate score contributions to identify MVP(s) automatically
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

    let maxScore = -1;
    for (const score of scoreMap.values()) {
      if (score > maxScore) {
        maxScore = score;
      }
    }

    const motmProfileIds = new Set<string>();
    if (maxScore > 0) {
      for (const [profileId, score] of scoreMap.entries()) {
        if (score === maxScore) {
          motmProfileIds.add(profileId);
        }
      }
    }

    // 3. Mark status as completed in DB
    await pool.query(`UPDATE public.events SET status = 'completed' WHERE id = $1`, [eventId]);

    // 4. Insert match result with the calculated MVP
    const firstMotm = motmProfileIds.size > 0 ? Array.from(motmProfileIds)[0] : undefined;
    await eventRepository.insertMatchResult({
      eventId,
      winningTeam: autoWinningTeam,
      manOfTheMatchId: firstMotm,
      submittedBy: event.host_id,
    });

    // 5. Enqueue BullMQ Points allocation job for async processing
    const settledAt = Date.now();
    await pointsQueue.add(
      'settle-batch',
      {
        eventId,
        winningTeam: autoWinningTeam,
        playerStats: [],
        settledAt,
        motmProfileIds: Array.from(motmProfileIds),
      },
      {
        attempts: 5,
        backoff: {
          type: 'exponential',
          delay: 5000,
        },
      }
    );
  }

  /**
   * Trigger autocompletes.
   */
  async triggerAutoComplete(): Promise<{ completedLive: number; completedScheduled: number }> {
    // 1. Find live events past ends_at
    const liveRes = await pool.query(
      `SELECT id FROM public.events WHERE status = 'live' AND ends_at < (NOW() AT TIME ZONE 'Asia/Kolkata')`
    );
    const liveEvents = liveRes.rows;
    for (const e of liveEvents) {
      try {
        await this.settleMatchSystem(e.id);
      } catch (err: any) {
        console.error(`[EventService] Error auto-settling event ${e.id}:`, err.message);
      }
    }

    // 2. Find scheduled events past ends_at + 1 hour that never checked in
    const scheduledRes = await pool.query(
      `SELECT id FROM public.events WHERE status = 'scheduled' AND ends_at < (NOW() AT TIME ZONE 'Asia/Kolkata') - INTERVAL '1 hour'`
    );
    const scheduledEvents = scheduledRes.rows;
    for (const e of scheduledEvents) {
      try {
        await pool.query(`UPDATE public.events SET status = 'completed' WHERE id = $1`, [e.id]);
      } catch (err: any) {
        console.error(`[EventService] Error auto-completing scheduled fallback event ${e.id}:`, err.message);
      }
    }

    return {
      completedLive: liveEvents.length,
      completedScheduled: scheduledEvents.length,
    };
  }

  /**
   * Log a scoring action for a live match (host only).
   */
  async logScore(
    userId: string,
    eventId: string,
    sport: string,
    details: {
      team: 'A' | 'B' | 'team_a' | 'team_b';
      scorer_member_id?: string;
      out_member_id?: string | null;
      minute?: number;
      outcome?: string;
      runs?: number;
      extra_type?: 'wide' | 'no_ball';
      dismissal_type?: 'caught' | 'bowled' | 'run_out' | 'lbw';
    }
  ): Promise<EventRow> {
    const event = await this.getEvent(eventId, userId);
    if (event.host_id !== userId) {
      throw new AppError(403, 'FORBIDDEN', 'Only the event host can record score logs.');
    }
    if (event.status !== 'live') {
      throw new AppError(409, 'MATCH_NOT_LIVE', 'Scores can only be updated for live matches.');
    }

    const teamMapped = (details.team === 'A' || details.team === 'team_a') ? 'team_a' : 'team_b';
    const teamLabel = teamMapped === 'team_a' ? 'Team A' : 'Team B';

    // Retrieve scorer details if specified
    let scorerName = 'Someone';
    if (details.scorer_member_id) {
      const roster = await eventRepository.getEventMembers(eventId);
      const scorer = roster.find((m) => m.id === details.scorer_member_id);
      if (scorer) {
        scorerName = scorer.guest_name ?? scorer.full_name ?? scorer.username ?? 'Athlete';
      }
    }

    if (sport === 'Football') {
      const currentScoreA = event.team_a_score ?? 0;
      const currentScoreB = event.team_b_score ?? 0;

      let newScoreA = currentScoreA;
      let newScoreB = currentScoreB;

      if (teamMapped === 'team_a') {
        newScoreA = currentScoreA + 1;
      } else if (teamMapped === 'team_b') {
        newScoreB = currentScoreB + 1;
      }

      // Decrement scoring corrections (if minute is not passed or if custom check)
      const isAdjustment = details.minute === undefined;
      const minuteVal = details.minute ?? 0;
      const logMessage = isAdjustment
        ? `Score adjusted: ${teamLabel} score is now ${teamMapped === 'team_a' ? newScoreA : newScoreB}`
        : `${minuteVal}' Goal - ${scorerName} (${teamLabel})`;

      // 1. Insert Match Log
      await eventRepository.insertMatchLog({
        eventId,
        team: teamMapped,
        scorerMemberId: details.scorer_member_id,
        minute: minuteVal,
        logType: 'goal',
        message: logMessage,
      });

      // 2. Update Event Score
      return eventRepository.updateMatchScore(eventId, {
        team_a_score: newScoreA,
        team_b_score: newScoreB,
      });
    } else if (sport === 'Cricket') {
      // Cricket fields logic
      const runsInput = details.runs ?? 0;
      const isWide = details.extra_type === 'wide';
      const isNoBall = details.extra_type === 'no_ball';
      const isWicket = details.outcome === 'wicket';

      const currentRuns = teamMapped === 'team_a' ? (event.team_a_score ?? 0) : (event.team_b_score ?? 0);
      const currentWickets = teamMapped === 'team_a' ? (event.team_a_wickets ?? 0) : (event.team_b_wickets ?? 0);
      const currentBalls = teamMapped === 'team_a' ? (event.team_a_balls ?? 0) : (event.team_b_balls ?? 0);

      let addRuns = runsInput;
      let addWickets = isWicket ? 1 : 0;
      let addBalls = (isWide || isNoBall) ? 0 : 1; // wide/noball do not count towards balls bowled in over

      if (isWide || isNoBall) {
        addRuns += 1; // +1 run penalty
      }

      const nextRuns = currentRuns + addRuns;
      const nextWickets = currentWickets + addWickets;
      const nextBalls = currentBalls + addBalls;

      const overStr = `${Math.floor(nextBalls / 6)}.${nextBalls % 6}`;

      // Determine who got out if wicket
      let outMemberId: string | null = null;
      let nextStrikerId = event.striker_id;
      let nextNonStrikerId = event.non_striker_id;
      let nextBowlerId = event.current_bowler_id;

      if (isWicket) {
        outMemberId = details.out_member_id ?? event.striker_id ?? null;
        if (outMemberId === event.striker_id) {
          nextStrikerId = null;
        } else if (outMemberId === event.non_striker_id) {
          nextNonStrikerId = null;
        }

        // Gully Cricket Wicket Fallback:
        // Check if there are any eligible batsmen left on the bench.
        const roster = await eventRepository.getEventMembers(eventId);
        const battingTeamMembers = roster.filter(
          (m) =>
            (teamMapped === 'team_a' && m.team === 'team_a') ||
            (teamMapped === 'team_b' && m.team === 'team_b')
        );

        // Find eligible bench batsmen (members who have not gotten out, and are not striker/non-striker/outMemberId)
        const benchBatsmen = battingTeamMembers.filter(
          (m) => !m.is_out && m.id !== nextStrikerId && m.id !== nextNonStrikerId && m.id !== outMemberId
        );

        if (benchBatsmen.length === 0) {
          // No players left on the bench!
          // If striker got out and non-striker is still standing, promote non-striker to striker!
          if (nextStrikerId === null && nextNonStrikerId !== null) {
            nextStrikerId = nextNonStrikerId;
            nextNonStrikerId = null;
          }
        }
      }

      // Check for strike rotation on runs (only if nobody got out and both striker/non-striker are set)
      if (!isWicket && nextStrikerId && nextNonStrikerId) {
        if (runsInput % 2 === 1) {
          const temp = nextStrikerId;
          nextStrikerId = nextNonStrikerId;
          nextNonStrikerId = temp;
        }
      }

      // Check for end of over (6 valid balls)
      const isOverComplete = addBalls > 0 && nextBalls > 0 && nextBalls % 6 === 0;
      if (isOverComplete) {
        if (nextStrikerId && nextNonStrikerId) {
          const temp = nextStrikerId;
          nextStrikerId = nextNonStrikerId;
          nextNonStrikerId = temp;
        }
        nextBowlerId = null; // Clear bowler, prompting selection of a new bowler
      }

      // Resolve scorer name for message
      let activeScorerId = isWicket ? outMemberId : event.striker_id;
      let batsmanName = 'Striker';
      if (activeScorerId) {
        const roster = await eventRepository.getEventMembers(eventId);
        const batsman = roster.find((m) => m.id === activeScorerId);
        if (batsman) {
          batsmanName = batsman.guest_name ?? batsman.full_name ?? batsman.username ?? 'Athlete';
        }
      }

      let message = `${overStr} Over - `;
      let logType = 'runs';

      if (isWicket) {
        message += `Wicket - ${batsmanName} ${details.dismissal_type ?? 'Bowled'} (${teamLabel})`;
        logType = 'wicket';
      } else if (isWide || isNoBall) {
        message += `Extra - ${details.extra_type} (+1 run) (${teamLabel})`;
        logType = 'extra';
      } else {
        message += `${batsmanName} scores ${runsInput} run(s) (${teamLabel})`;
      }

      // 1. Insert Match Log
      await eventRepository.insertMatchLog({
        eventId,
        team: teamMapped,
        scorerMemberId: activeScorerId,
        bowlerMemberId: event.current_bowler_id,
        overNumber: parseFloat(overStr),
        logType,
        runs: addRuns,
        extraType: details.extra_type,
        dismissalType: details.dismissal_type,
        message,
      });

      // 2. Update Event Score state
      const updates: any = {
        striker_id: nextStrikerId,
        non_striker_id: nextNonStrikerId,
        current_bowler_id: nextBowlerId,
      };

      if (teamMapped === 'team_a') {
        updates.team_a_score = nextRuns;
        updates.team_a_wickets = nextWickets;
        updates.team_a_balls = nextBalls;
      } else {
        updates.team_b_score = nextRuns;
        updates.team_b_wickets = nextWickets;
        updates.team_b_balls = nextBalls;
      }

      // Automatically determine innings completion and chase target logic
      let firstBattingTeam: 'team_a' | 'team_b' = 'team_a';
      if (event.toss_winner_team === 'team_a') {
        firstBattingTeam = event.toss_decision === 'bat' ? 'team_a' : 'team_b';
      } else if (event.toss_winner_team === 'team_b') {
        firstBattingTeam = event.toss_decision === 'bat' ? 'team_b' : 'team_a';
      }
      const secondBattingTeam: 'team_a' | 'team_b' = firstBattingTeam === 'team_a' ? 'team_b' : 'team_a';

      const maxBalls = (event.max_overs ?? 10) * 6;
      const firstBattingScore = firstBattingTeam === teamMapped ? nextRuns : (firstBattingTeam === 'team_a' ? (event.team_a_score ?? 0) : (event.team_b_score ?? 0));
      const targetRuns = firstBattingScore + 1;

      if (teamMapped === firstBattingTeam) {
        const isInningsOver = (nextStrikerId === null && nextNonStrikerId === null) || (nextBalls >= maxBalls);
        if (isInningsOver) {
          updates.current_batting = secondBattingTeam;
          updates.striker_id = null;
          updates.non_striker_id = null;
          updates.current_bowler_id = null;

          const overNotation = `${Math.floor(nextBalls / 6)}.${nextBalls % 6}`;
          const endMessage = `Innings 1 Complete! Team ${teamLabel.toUpperCase()} scored ${nextRuns}/${nextWickets} in ${overNotation} overs. Team ${secondBattingTeam.toUpperCase()} needs ${targetRuns} runs to win.`;
          
          await eventRepository.insertMatchLog({
            eventId,
            team: teamMapped,
            logType: 'score_update',
            message: endMessage,
          });
        }
      } else if (teamMapped === secondBattingTeam) {
        const hasChased = nextRuns >= targetRuns;
        const isInningsOver = (nextStrikerId === null && nextNonStrikerId === null) || (nextBalls >= maxBalls);

        if (hasChased) {
          const winMessage = `Match Over! Team ${teamLabel.toUpperCase()} successfully chased the target! Score: ${nextRuns}/${nextWickets} (Target: ${targetRuns})`;
          await eventRepository.insertMatchLog({
            eventId,
            team: teamMapped,
            logType: 'score_update',
            message: winMessage,
          });
        } else if (isInningsOver) {
          const winMessage = `Match Over! Team ${teamLabel.toUpperCase()} failed to chase target. Score: ${nextRuns}/${nextWickets} (Target: ${targetRuns}). Team ${firstBattingTeam.toUpperCase()} wins!`;
          await eventRepository.insertMatchLog({
            eventId,
            team: teamMapped,
            logType: 'score_update',
            message: winMessage,
          });
        }
      }

      return eventRepository.updateMatchScore(eventId, updates);
    } else {
      // Fallback for other sports (Badminton, Basketball, Tennis)
      const currentScoreA = event.team_a_score ?? 0;
      const currentScoreB = event.team_b_score ?? 0;

      let newScoreA = teamMapped === 'team_a' ? currentScoreA + 1 : currentScoreA;
      let newScoreB = teamMapped === 'team_b' ? currentScoreB + 1 : currentScoreB;

      await eventRepository.insertMatchLog({
        eventId,
        team: teamMapped,
        scorerMemberId: details.scorer_member_id,
        logType: 'score_update',
        message: `Point - ${scorerName} (${teamLabel}). Score: ${newScoreA} - ${newScoreB}`,
      });

      return eventRepository.updateMatchScore(eventId, {
        team_a_score: newScoreA,
        team_b_score: newScoreB,
      });
    }
  }

  /**
   * Fetch timeline logs for an event match (privacy-validated).
   */
  async getMatchLogs(userId: string | undefined, eventId: string): Promise<any[]> {
    await this.getEvent(eventId, userId);
    return eventRepository.getMatchLogs(eventId);
  }

  /**
   * Settle and complete a live match (host only).
   * Triggers BullMQ points-award-batch job.
   */
  async settleMatch(
    userId: string,
    eventId: string,
    data: {
      winning_team: 'A' | 'B' | 'Draw';
      man_of_the_match_id?: string;
      player_stats?: Array<{ profile_id: string; goals?: number }>;
    }
  ): Promise<{ success: boolean; event_status: string; points_allocated: any[] }> {
    const event = await this.getEvent(eventId, userId);
    if (event.host_id !== userId) {
      throw new AppError(403, 'FORBIDDEN', 'Only the event host can settle the match results.');
    }

    // 1. Calculate winning team automatically based on scores
    let autoWinningTeam: 'A' | 'B' | 'Draw' = 'Draw';
    const scoreA = event.team_a_score ?? 0;
    const scoreB = event.team_b_score ?? 0;
    if (scoreA > scoreB) {
      autoWinningTeam = 'A';
    } else if (scoreB > scoreA) {
      autoWinningTeam = 'B';
    }

    // 2. Calculate score contributions to identify MVP(s) automatically BEFORE deleting logs
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

    for (const p of data.player_stats || []) {
      if (p.profile_id && p.goals !== undefined) {
        const existing = scoreMap.get(p.profile_id) ?? 0;
        scoreMap.set(p.profile_id, Math.max(existing, p.goals));
      }
    }

    let maxScore = -1;
    for (const score of scoreMap.values()) {
      if (score > maxScore) {
        maxScore = score;
      }
    }

    const motmProfileIds = new Set<string>();
    if (maxScore > 0) {
      for (const [profileId, score] of scoreMap.entries()) {
        if (score === maxScore) {
          motmProfileIds.add(profileId);
        }
      }
    }

    if (motmProfileIds.size === 0 && data.man_of_the_match_id) {
      motmProfileIds.add(data.man_of_the_match_id);
    }

    // Check if current time is past booking ends_at
    const nowTime = new Date();
    const bookingEnds = new Date(event.ends_at);
    const isBookingExpired = nowTime >= bookingEnds;

    // 3. Mark status as completed if booking expired, otherwise reset scoreboard and keep live
    if (isBookingExpired) {
      await pool.query(`UPDATE public.events SET status = 'completed' WHERE id = $1`, [eventId]);
    } else {
      await pool.query(
        `UPDATE public.events 
         SET team_a_score = 0, team_b_score = 0, 
             team_a_wickets = 0, team_b_wickets = 0, 
             team_a_balls = 0, team_b_balls = 0, 
             current_batting = 'team_a'
         WHERE id = $1`,
        [eventId]
      );
      await pool.query(`DELETE FROM public.match_logs WHERE event_id = $1`, [eventId]);
    }

    // 4. Insert match result with the calculated MVP
    const firstMotm = motmProfileIds.size > 0 ? Array.from(motmProfileIds)[0] : undefined;
    await eventRepository.insertMatchResult({
      eventId,
      winningTeam: autoWinningTeam,
      manOfTheMatchId: firstMotm,
      submittedBy: userId,
    });

    // 5. Calculate points allocation projection to return to client
    const roster = await eventRepository.getEventMembers(eventId);
    const officialRoster = roster.filter((m) => m.is_official && m.profile_id);

    const allocationProjection: any[] = [];
    for (const member of officialRoster) {
      const pId = member.profile_id!;
      const isWinner =
        (autoWinningTeam === 'A' && member.team === 'team_a') ||
        (autoWinningTeam === 'B' && member.team === 'team_b');
      const isDraw = autoWinningTeam === 'Draw';
      const isMOTM = motmProfileIds.has(pId);

      let pts = 20; // Default Loss
      let reason = 'Loss';

      if (isWinner) {
        pts = 50;
        reason = 'Win';
      } else if (isDraw) {
        pts = 30;
        reason = 'Draw';
      }

      if (isMOTM) {
        pts += 20;
        reason += ' + MVP';
      }

      allocationProjection.push({
        profile_id: pId,
        points: pts,
        reason: `${reason} points`,
      });
    }

    // 6. Enqueue BullMQ Points allocation job for async processing
    const settledAt = Date.now();
    await pointsQueue.add(
      'settle-batch',
      {
        eventId,
        winningTeam: autoWinningTeam,
        manOfTheMatchId: firstMotm,
        playerStats: data.player_stats || [],
        settledAt,
        motmProfileIds: Array.from(motmProfileIds),
      },
      {
        attempts: 5,
        backoff: {
          type: 'exponential',
          delay: 5000,
        },
      }
    );

    // Fetch final event status to return to client
    const finalEventRes = await pool.query(`SELECT status FROM public.events WHERE id = $1`, [eventId]);
    const finalStatus = finalEventRes.rows[0]?.status ?? 'completed';

    return {
      success: true,
      event_status: finalStatus,
      points_allocated: allocationProjection,
    };
  }

  /**
   * Set up cricket toss results.
   */
  async setupToss(
    userId: string,
    eventId: string,
    tossWinnerTeam: 'team_a' | 'team_b',
    tossDecision: 'bat' | 'bowl',
    maxOvers: number
  ): Promise<EventRow> {
    const event = await eventRepository.findById(eventId);
    if (!event) {
      throw new Error('EVENT_NOT_FOUND');
    }
    if (event.host_id !== userId) {
      throw new Error('FORBIDDEN');
    }

    // Determine initial batting team based on toss decision
    let currentBatting: 'team_a' | 'team_b' = 'team_a';
    if (tossWinnerTeam === 'team_a') {
      currentBatting = tossDecision === 'bat' ? 'team_a' : 'team_b';
    } else {
      currentBatting = tossDecision === 'bat' ? 'team_b' : 'team_a';
    }

    return eventRepository.updateMatchScore(eventId, {
      toss_winner_team: tossWinnerTeam,
      toss_decision: tossDecision,
      current_batting: currentBatting,
      max_overs: maxOvers,
    });
  }

  /**
   * Set active striker, non-striker, or bowler.
   */
  async setActiveCricketPlayers(
    userId: string,
    eventId: string,
    data: { striker_id?: string | null; non_striker_id?: string | null; current_bowler_id?: string | null }
  ): Promise<EventRow> {
    const event = await eventRepository.findById(eventId);
    if (!event) {
      throw new Error('EVENT_NOT_FOUND');
    }
    if (event.host_id !== userId) {
      throw new Error('FORBIDDEN');
    }

    const updates: any = {};
    if (data.striker_id !== undefined) updates.striker_id = data.striker_id;
    if (data.non_striker_id !== undefined) updates.non_striker_id = data.non_striker_id;
    if (data.current_bowler_id !== undefined) updates.current_bowler_id = data.current_bowler_id;

    return eventRepository.updateMatchScore(eventId, updates);
  }
}

export const eventService = new EventService();
