import { eventRepository, EventRow, EventMemberRow } from '../repositories/eventRepository.js';
import { followRepository } from '../repositories/followRepository.js';
import { pool } from '../config/db.js';

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
    }
  ): Promise<EventRow> {
    try {
      return await eventRepository.createEvent(userId, data);
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
  async addGuest(userId: string, eventId: string, guestName: string): Promise<EventMemberRow> {
    return eventRepository.addGuest(userId, eventId, guestName);
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
    team: 'unassigned' | 'team_a' | 'team_b'
  ): Promise<EventMemberRow> {
    return eventRepository.assignTeam(userId, eventId, memberId, team);
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
   * Trigger autocompletes.
   */
  async triggerAutoComplete(): Promise<{ completedLive: number; completedScheduled: number }> {
    const completedLive = await eventRepository.autoCompleteLiveEvents();
    const completedScheduled = await eventRepository.autoCompleteScheduledFallback();
    return { completedLive, completedScheduled };
  }
}

export const eventService = new EventService();
