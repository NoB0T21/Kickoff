import { Type, Static } from '@sinclair/typebox';

// ── Enums matching the DB types ──

export const SportType = Type.Union([
  Type.Literal('Football'),
  Type.Literal('Cricket'),
  Type.Literal('Badminton'),
  Type.Literal('Basketball'),
  Type.Literal('Tennis'),
]);

export const SkillLevelType = Type.Union([
  Type.Literal('Beginner'),
  Type.Literal('Intermediate'),
  Type.Literal('Advanced'),
  Type.Literal('Semi-Pro'),
]);

// ── Request Schemas ──

export const UpdateProfileBody = Type.Object({
  username: Type.Optional(Type.String({ minLength: 3, maxLength: 50, pattern: '^[a-zA-Z0-9_]+$' })),
  full_name: Type.Optional(Type.String({ minLength: 1, maxLength: 100 })),
  avatar_url: Type.Optional(Type.String({ format: 'uri' })),
  primary_sport: Type.Optional(SportType),
  skill_level: Type.Optional(SkillLevelType),
});

export type UpdateProfileBodyType = Static<typeof UpdateProfileBody>;

export const UsernameCheckQuery = Type.Object({
  username: Type.String({ minLength: 3, maxLength: 50, pattern: '^[a-zA-Z0-9_]+$' }),
});

export type UsernameCheckQueryType = Static<typeof UsernameCheckQuery>;

export const ProfileIdParams = Type.Object({
  id: Type.String({ format: 'uuid' }),
});

export type ProfileIdParamsType = Static<typeof ProfileIdParams>;

export const PaginationQuery = Type.Object({
  cursor: Type.Optional(Type.String()),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 50, default: 20 })),
});

export type PaginationQueryType = Static<typeof PaginationQuery>;

// ── Auth Schemas ──

export const ForgotPasswordBody = Type.Object({
  email: Type.String({ format: 'email' }),
});

export type ForgotPasswordBodyType = Static<typeof ForgotPasswordBody>;

export const ResetPasswordBody = Type.Object({
  token: Type.String({ minLength: 1 }),
  new_password: Type.String({ minLength: 8 }),
});

export type ResetPasswordBodyType = Static<typeof ResetPasswordBody>;

// ── Custom OTP Auth Schemas ──

export const SignupOtpBody = Type.Object({
  email: Type.String({ format: 'email' }),
  password: Type.String({ minLength: 8 }),
});
export type SignupOtpBodyType = Static<typeof SignupOtpBody>;

export const VerifyOtpBody = Type.Object({
  email: Type.String({ format: 'email' }),
  password: Type.String({ minLength: 8 }),
  token: Type.String({ minLength: 6, maxLength: 6 }),
});
export type VerifyOtpBodyType = Static<typeof VerifyOtpBody>;

export const LoginOtpBody = Type.Object({
  email: Type.String({ format: 'email' }),
});
export type LoginOtpBodyType = Static<typeof LoginOtpBody>;

export const VerifyLoginOtpBody = Type.Object({
  email: Type.String({ format: 'email' }),
  token: Type.String({ minLength: 6, maxLength: 6 }),
});
export type VerifyLoginOtpBodyType = Static<typeof VerifyLoginOtpBody>;

