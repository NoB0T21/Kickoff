import { pool } from '../config/db.js';

export interface ProfileRow {
  id: string;
  username: string;
  full_name: string;
  avatar_url: string | null;
  skill_level: string;
  primary_sport: string;
  total_points: number;
  followers_count: number;
  following_count: number;
  has_completed_onboarding: boolean;
  avatar_variants: Record<string, string>;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface UpdateProfileData {
  username?: string;
  full_name?: string;
  avatar_url?: string;
  primary_sport?: string;
  skill_level?: string;
}

export const profileRepository = {
  /**
   * Find a profile by ID, excluding soft-deleted profiles.
   */
  async findById(id: string): Promise<ProfileRow | null> {
    const result = await pool.query(
      `SELECT * FROM public.profiles WHERE id = $1 AND deleted_at IS NULL`,
      [id],
    );
    return result.rows[0] ?? null;
  },

  /**
   * Update a profile. Dynamically builds the SET clause from provided fields.
   * Sets has_completed_onboarding = true when required fields are all present.
   */
  async updateProfile(userId: string, data: UpdateProfileData): Promise<ProfileRow> {
    const setClauses: string[] = [];
    const values: unknown[] = [];
    let paramIndex = 1;

    for (const [key, value] of Object.entries(data)) {
      if (value !== undefined) {
        setClauses.push(`${key} = $${paramIndex}`);
        values.push(value);
        paramIndex++;
      }
    }

    setClauses.push(`updated_at = NOW()`);

    // Build the query — also conditionally set has_completed_onboarding
    const query = `
      UPDATE public.profiles
      SET ${setClauses.join(', ')},
          has_completed_onboarding = CASE
            WHEN COALESCE($${paramIndex}::varchar, username) NOT LIKE 'user\\_%'
              AND COALESCE($${paramIndex + 1}::varchar, full_name) != 'Athlete'
              AND COALESCE($${paramIndex + 2}::varchar, primary_sport::text) IS NOT NULL
              AND COALESCE($${paramIndex + 3}::varchar, skill_level::text) IS NOT NULL
            THEN true
            ELSE has_completed_onboarding
          END
      WHERE id = $${paramIndex + 4} AND deleted_at IS NULL
      RETURNING *
    `;

    values.push(
      data.username ?? null,
      data.full_name ?? null,
      data.primary_sport ?? null,
      data.skill_level ?? null,
      userId,
    );

    const result = await pool.query(query, values);
    return result.rows[0];
  },

  /**
   * Check if a username is available (case-insensitive).
   */
  async isUsernameAvailable(username: string): Promise<boolean> {
    const result = await pool.query(
      `SELECT 1 FROM public.profiles WHERE LOWER(username) = LOWER($1) AND deleted_at IS NULL LIMIT 1`,
      [username],
    );
    return result.rows.length === 0;
  },

  /**
   * Soft-delete a profile: set deleted_at, anonymize PII.
   */
  async softDelete(userId: string): Promise<void> {
    await pool.query(
      `UPDATE public.profiles
       SET deleted_at = NOW(),
           full_name = 'Deleted User',
           avatar_url = NULL,
           avatar_variants = '{}'::JSONB,
           updated_at = NOW()
       WHERE id = $1 AND deleted_at IS NULL`,
      [userId],
    );
  },

  /**
   * Search profiles matching a query case-insensitively.
   */
  async searchProfiles(query: string, limit = 25): Promise<ProfileRow[]> {
    const searchPattern = `%${query}%`;
    const result = await pool.query(
      `SELECT * FROM public.profiles 
       WHERE (username ILIKE $1 OR full_name ILIKE $1) 
         AND deleted_at IS NULL 
       LIMIT $2`,
      [searchPattern, limit]
    );
    return result.rows as ProfileRow[];
  },
};
