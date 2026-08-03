import { pool } from '../config/db.js';

export interface TurfRow {
  id: string;
  owner_id: string | null;
  name: string;
  location_name: string;
  latitude: number;
  longitude: number;
  description: string | null;
  sports: string[];
  image_urls: string[];
  hourly_rate: string;
  open_hour: number;
  close_hour: number;
  created_at: string;
  distance_km?: number;
}

export interface SlotRow {
  id: string;
  turf_id: string;
  slot_date: string;
  start_hour: number;
  end_hour: number;
  price: string;
  status: 'available' | 'locked' | 'booked';
  locked_by: string | null;
  locked_until: string | null;
  created_at: string;
}

export const turfRepository = {
  /**
   * Search turfs using geo distance, sports filters, and cursor pagination.
   */
  async findTurfs(params: {
    lat: number;
    lng: number;
    sport?: string;
    date?: string;
    cursor?: string;
    limit: number;
  }): Promise<{ data: TurfRow[]; next_cursor: string | null }> {
    const values: unknown[] = [params.lat, params.lng];
    let queryIndex = 3;

    let cursorCondition = '';
    
    // If a cursor (turf ID) is provided, fetch its distance first to paginate correctly
    if (params.cursor) {
      const cursorResult = await pool.query(
        `SELECT id, latitude, longitude,
                (earth_distance(ll_to_earth(latitude, longitude), ll_to_earth($1, $2)) / 1000) as distance
         FROM public.turfs WHERE id = $3`,
        [params.lat, params.lng, params.cursor]
      );
      
      if (cursorResult.rows.length > 0) {
        const cursorDistance = cursorResult.rows[0].distance;
        cursorCondition = `AND (
          (earth_distance(ll_to_earth(latitude, longitude), ll_to_earth($1, $2)) / 1000) > $${queryIndex}
          OR (
            (earth_distance(ll_to_earth(latitude, longitude), ll_to_earth($1, $2)) / 1000) = $${queryIndex}
            AND id > $${queryIndex + 1}
          )
        )`;
        values.push(cursorDistance, params.cursor);
        queryIndex += 2;
      }
    }

    let sportCondition = '';
    if (params.sport) {
      sportCondition = `AND sports @> ARRAY[$${queryIndex}::sport_type]`;
      values.push(params.sport);
      queryIndex++;
    }

    const limitValueIndex = queryIndex;
    values.push(params.limit + 1); // Fetch limit + 1 to check if there is a next page

    const sql = `
      SELECT id, name, location_name, latitude, longitude, description, sports::text[] as sports, image_urls::text[] as image_urls, hourly_rate, open_hour, close_hour, created_at,
             (earth_distance(ll_to_earth(latitude, longitude), ll_to_earth($1, $2)) / 1000) as distance_km
      FROM public.turfs
      WHERE 1=1
      ${cursorCondition}
      ${sportCondition}
      ORDER BY distance_km ASC, id ASC
      LIMIT $${limitValueIndex}
    `;

    const result = await pool.query(sql, values);
    const rows = result.rows as TurfRow[];

    const hasNextPage = rows.length > params.limit;
    const data = hasNextPage ? rows.slice(0, params.limit) : rows;
    const next_cursor = hasNextPage ? data[data.length - 1].id : null;

    return {
      data,
      next_cursor,
    };
  },

  /**
   * Get all slots for a turf on a specific date.
   */
  async findSlotsByTurfAndDate(turfId: string, date: string): Promise<SlotRow[]> {
    const result = await pool.query(
      `SELECT id, turf_id, slot_date::text, start_hour, end_hour, price, status, locked_by, locked_until::text, created_at
       FROM public.slots
       WHERE turf_id = $1 AND slot_date = $2
       ORDER BY start_hour ASC`,
      [turfId, date]
    );
    return result.rows as SlotRow[];
  },

  /**
   * Helper to insert a turf (useful for seeding/testing).
   */
  async createTurf(turf: Omit<TurfRow, 'id' | 'created_at'>): Promise<TurfRow> {
    const result = await pool.query(
      `INSERT INTO public.turfs (owner_id, name, location_name, latitude, longitude, description, sports, image_urls, hourly_rate, open_hour, close_hour)
       VALUES ($1, $2, $3, $4, $5, $6, $7::sport_type[], $8, $9, $10, $11)
       RETURNING id, owner_id, name, location_name, latitude, longitude, description, sports::text[] as sports, image_urls::text[] as image_urls, hourly_rate, open_hour, close_hour, created_at`,
      [
        turf.owner_id,
        turf.name,
        turf.location_name,
        turf.latitude,
        turf.longitude,
        turf.description,
        turf.sports,
        turf.image_urls,
        turf.hourly_rate,
        turf.open_hour,
        turf.close_hour,
      ]
    );
    return result.rows[0];
  },

  /**
   * Batch insert slots for a turf date (useful for generator cron).
   */
  async createSlots(slots: Omit<SlotRow, 'id' | 'created_at' | 'locked_by' | 'locked_until'>[]): Promise<void> {
    if (slots.length === 0) return;
    
    const setClauses: string[] = [];
    const values: unknown[] = [];
    let pIndex = 1;

    for (const slot of slots) {
      setClauses.push(`($${pIndex}, $${pIndex + 1}, $${pIndex + 2}, $${pIndex + 3}, $${pIndex + 4}, $${pIndex + 5}::slot_status)`);
      values.push(slot.turf_id, slot.slot_date, slot.start_hour, slot.end_hour, slot.price, slot.status);
      pIndex += 6;
    }

    const query = `
      INSERT INTO public.slots (turf_id, slot_date, start_hour, end_hour, price, status)
      VALUES ${setClauses.join(', ')}
      ON CONFLICT (turf_id, slot_date, start_hour) DO NOTHING
    `;

    await pool.query(query, values);
  }
};
