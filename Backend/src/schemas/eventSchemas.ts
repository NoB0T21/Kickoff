import { Type, Static } from '@sinclair/typebox';

const SportTypeEnum = Type.Union([
  Type.Literal('Football'),
  Type.Literal('Cricket'),
  Type.Literal('Badminton'),
  Type.Literal('Basketball'),
  Type.Literal('Tennis'),
]);

const EventPrivacyEnum = Type.Union([
  Type.Literal('public'),
  Type.Literal('private'),
]);

const EventStatusEnum = Type.Union([
  Type.Literal('scheduled'),
  Type.Literal('live'),
  Type.Literal('completed'),
  Type.Literal('cancelled'),
]);

const RosterTeamEnum = Type.Union([
  Type.Literal('unassigned'),
  Type.Literal('team_a'),
  Type.Literal('team_b'),
  Type.Literal('A'),
  Type.Literal('B'),
]);

// POST /api/events
export const CreateEventBody = Type.Object({
  booking_id: Type.String({ format: 'uuid' }),
  title: Type.String({ minLength: 1 }),
  description: Type.Optional(Type.String()),
  sport: SportTypeEnum,
  privacy: EventPrivacyEnum,
  capacity: Type.Integer({ minimum: 1 }),
});
export type CreateEventBodyType = Static<typeof CreateEventBody>;

// GET /api/events query
export const GetEventsQuery = Type.Object({
  sport: Type.Optional(SportTypeEnum),
  status: Type.Optional(EventStatusEnum),
  cursor: Type.Optional(Type.String()),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 50, default: 20 })),
});
export type GetEventsQueryType = Static<typeof GetEventsQuery>;

// Params with ID
export const EventIdParams = Type.Object({
  id: Type.String({ format: 'uuid' }),
});
export type EventIdParamsType = Static<typeof EventIdParams>;

// Params for invite token
export const InviteTokenParams = Type.Object({
  token: Type.String({ minLength: 1 }),
});
export type InviteTokenParamsType = Static<typeof InviteTokenParams>;

// POST /api/events/:id/roster/guest
export const AddGuestBody = Type.Object({
  guest_name: Type.Optional(Type.String({ minLength: 1 })),
  player_name: Type.Optional(Type.String({ minLength: 1 })),
  team: Type.Optional(RosterTeamEnum),
});
export type AddGuestBodyType = Static<typeof AddGuestBody>;

// DELETE /api/events/:id/roster/:member_id
export const EventMemberParams = Type.Object({
  id: Type.String({ format: 'uuid' }),
  member_id: Type.String({ format: 'uuid' }),
});
export type EventMemberParamsType = Static<typeof EventMemberParams>;

// PATCH/PUT /api/events/:id/roster/:member_id/team
export const AssignTeamBody = Type.Object({
  team: RosterTeamEnum,
});
export type AssignTeamBodyType = Static<typeof AssignTeamBody>;

// PATCH /api/events/:id
export const UpdateEventBody = Type.Object({
  title: Type.Optional(Type.String({ minLength: 1 })),
  description: Type.Optional(Type.String()),
  capacity: Type.Optional(Type.Integer({ minimum: 1 })),
});
export type UpdateEventBodyType = Static<typeof UpdateEventBody>;

// POST /api/events/:id/check-in
export const CheckInBody = Type.Object({
  qr_check_in_code: Type.Optional(Type.String({ minLength: 1 })),
  qr_code: Type.Optional(Type.String({ minLength: 1 })),
});
export type CheckInBodyType = Static<typeof CheckInBody>;

// POST /api/events/:id/score/log
export const LogScoreBody = Type.Object({
  sport: SportTypeEnum,
  details: Type.Object({
    team: Type.Union([Type.Literal('A'), Type.Literal('B'), Type.Literal('team_a'), Type.Literal('team_b')]),
    scorer_member_id: Type.Optional(Type.String({ format: 'uuid' })),
    minute: Type.Optional(Type.Integer({ minimum: 0 })),
    // Cricket fields
    outcome: Type.Optional(Type.String()),
    runs: Type.Optional(Type.Integer({ minimum: 0 })),
    extra_type: Type.Optional(Type.Union([Type.Literal('wide'), Type.Literal('no_ball')])),
    dismissal_type: Type.Optional(Type.Union([Type.Literal('caught'), Type.Literal('bowled'), Type.Literal('run_out'), Type.Literal('lbw')])),
  }),
});
export type LogScoreBodyType = Static<typeof LogScoreBody>;

// POST /api/events/:id/settle
export const PlayerStatItem = Type.Object({
  profile_id: Type.String({ format: 'uuid' }),
  goals: Type.Optional(Type.Integer({ minimum: 0 })),
});

export const SettleMatchBody = Type.Object({
  winning_team: Type.Union([Type.Literal('A'), Type.Literal('B'), Type.Literal('Draw')]),
  man_of_the_match_id: Type.Optional(Type.String({ format: 'uuid' })),
  player_stats: Type.Optional(Type.Array(PlayerStatItem)),
});
export type SettleMatchBodyType = Static<typeof SettleMatchBody>;

