import { pool } from '../config/db.js';

export interface FollowerRow {
  id: string;
  username: string;
  full_name: string;
  avatar_url: string | null;
}

interface CursorParts {
  created_at: string;
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

function encodeCursor(created_at: string, id: string): string {
  return Buffer.from(JSON.stringify({ created_at, id })).toString('base64');
}

export const followRepository = {
  /**
   * Insert a follow relationship.
   */
  async follow(followerId: string, followingId: string): Promise<void> {
    await pool.query(
      `INSERT INTO public.follows (follower_id, following_id) VALUES ($1, $2)`,
      [followerId, followingId],
    );
  },

  /**
   * Delete a follow relationship.
   */
  async unfollow(followerId: string, followingId: string): Promise<boolean> {
    const result = await pool.query(
      `DELETE FROM public.follows WHERE follower_id = $1 AND following_id = $2`,
      [followerId, followingId],
    );
    return (result.rowCount ?? 0) > 0;
  },

  /**
   * Check if a follow relationship exists.
   */
  async isFollowing(followerId: string, followingId: string): Promise<boolean> {
    const result = await pool.query(
      `SELECT 1 FROM public.follows WHERE follower_id = $1 AND following_id = $2 LIMIT 1`,
      [followerId, followingId],
    );
    return result.rows.length > 0;
  },

  /**
   * Get paginated followers for a profile (cursor-based).
   */
  async getFollowers(
    profileId: string,
    cursor?: string,
    limit: number = 20,
  ): Promise<{ data: FollowerRow[]; next_cursor: string | null }> {
    const values: unknown[] = [profileId, limit + 1]; // fetch one extra to know if there's a next page
    let cursorClause = '';

    if (cursor) {
      const parts = decodeCursor(cursor);
      if (parts) {
        cursorClause = `AND (f.created_at, f.follower_id) < ($3, $4)`;
        values.push(parts.created_at, parts.id);
      }
    }

    const result = await pool.query(
      `SELECT p.id, p.username, p.full_name, p.avatar_url, f.created_at AS follow_created_at
       FROM public.follows f
       JOIN public.profiles p ON p.id = f.follower_id AND p.deleted_at IS NULL
       WHERE f.following_id = $1 ${cursorClause}
       ORDER BY f.created_at DESC, f.follower_id DESC
       LIMIT $2`,
      values,
    );

    const hasMore = result.rows.length > limit;
    const rows = hasMore ? result.rows.slice(0, limit) : result.rows;

    const data: FollowerRow[] = rows.map((r: any) => ({
      id: r.id,
      username: r.username,
      full_name: r.full_name,
      avatar_url: r.avatar_url,
    }));

    const next_cursor = hasMore
      ? encodeCursor(rows[rows.length - 1].follow_created_at, rows[rows.length - 1].id)
      : null;

    return { data, next_cursor };
  },

  /**
   * Get paginated following list for a profile (cursor-based).
   */
  async getFollowing(
    profileId: string,
    cursor?: string,
    limit: number = 20,
  ): Promise<{ data: FollowerRow[]; next_cursor: string | null }> {
    const values: unknown[] = [profileId, limit + 1];
    let cursorClause = '';

    if (cursor) {
      const parts = decodeCursor(cursor);
      if (parts) {
        cursorClause = `AND (f.created_at, f.following_id) < ($3, $4)`;
        values.push(parts.created_at, parts.id);
      }
    }

    const result = await pool.query(
      `SELECT p.id, p.username, p.full_name, p.avatar_url, f.created_at AS follow_created_at
       FROM public.follows f
       JOIN public.profiles p ON p.id = f.following_id AND p.deleted_at IS NULL
       WHERE f.follower_id = $1 ${cursorClause}
       ORDER BY f.created_at DESC, f.following_id DESC
       LIMIT $2`,
      values,
    );

    const hasMore = result.rows.length > limit;
    const rows = hasMore ? result.rows.slice(0, limit) : result.rows;

    const data: FollowerRow[] = rows.map((r: any) => ({
      id: r.id,
      username: r.username,
      full_name: r.full_name,
      avatar_url: r.avatar_url,
    }));

    const next_cursor = hasMore
      ? encodeCursor(rows[rows.length - 1].follow_created_at, rows[rows.length - 1].id)
      : null;

    return { data, next_cursor };
  },
};
