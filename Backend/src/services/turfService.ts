import { turfRepository, TurfRow, SlotRow } from '../repositories/turfRepository.js';

class TurfService {
  async searchTurfs(params: {
    lat: number;
    lng: number;
    sport?: string;
    date?: string;
    cursor?: string;
    limit: number;
  }): Promise<{ data: TurfRow[]; next_cursor: string | null }> {
    return turfRepository.findTurfs(params);
  }

  async getSlotsForTurfAndDate(turfId: string, date: string): Promise<SlotRow[]> {
    return turfRepository.findSlotsByTurfAndDate(turfId, date);
  }
}

export const turfService = new TurfService();
