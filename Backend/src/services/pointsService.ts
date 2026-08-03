import { pool } from '../config/db.js';

export type PointsReasonType = 'match_participation' | 'match_win' | 'match_draw' | 'man_of_the_match' | 'achievement_unlock';

export const pointsService = {
  /**
   * Idempotently awards points to a user.
   * Leverages database unique indexes (uq_points_event_award, uq_points_idempotency_key)
   * with ON CONFLICT DO NOTHING to prevent duplicate awards.
   */
  async awardPoints(params: {
    profileId: string;
    eventId?: string;
    points: number;
    reasonType: PointsReasonType;
    reason: string;
    idempotencyKey?: string;
  }): Promise<void> {
    const { profileId, eventId, points, reasonType, reason, idempotencyKey } = params;

    await pool.query(
      `INSERT INTO public.points_transactions (
        profile_id, event_id, points_awarded, reason_type, reason, idempotency_key
      ) VALUES ($1, $2, $3, $4::points_reason_type, $5, $6)
       ON CONFLICT DO NOTHING`,
      [
        profileId,
        eventId ?? null,
        points,
        reasonType,
        reason,
        idempotencyKey ?? null,
      ]
    );
  },
};
