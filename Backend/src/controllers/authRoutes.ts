import { FastifyInstance } from 'fastify';
import { supabaseAdmin } from '../config/supabase.js';
import { pool } from '../config/db.js';
import { queueEmail } from '../services/emailService.js';
import {
  ForgotPasswordBody,
  ForgotPasswordBodyType,
  ResetPasswordBody,
  ResetPasswordBodyType,
  SignupOtpBody,
  SignupOtpBodyType,
  VerifyOtpBody,
  VerifyOtpBodyType,
} from '../schemas/profileSchemas.js';

export async function authRoutes(server: FastifyInstance) {
  /**
   * POST /api/auth/signup-otp
   * Generates a 6-digit OTP and queues it to be sent via the background email queue.
   */
  server.post<{ Body: SignupOtpBodyType }>(
    '/api/auth/signup-otp',
    { schema: { body: SignupOtpBody } },
    async (request, reply) => {
      const { email } = request.body;
      console.log(email)
      // 1. Check if user already exists
      const dbClient = await pool.connect();
      try {
        const checkRes = await dbClient.query('SELECT id FROM auth.users WHERE email = $1', [email]);
        if (checkRes.rows.length > 0) {
          return reply.code(409).send({
            error: {
              code: 'EMAIL_ALREADY_REGISTERED',
              message: 'An account with this email already exists.',
            },
          });
        }

        // 2. Generate 6-digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes expiry

        // 3. Save to database (Clean up previous OTPs for this email first)
        await dbClient.query('DELETE FROM public.otps WHERE email = $1', [email]);
        await dbClient.query(
          'INSERT INTO public.otps (email, otp, expires_at) VALUES ($1, $2, $3)',
          [email, otp, expiresAt]
        );

        // 4. Queue the email delivery job
        await queueEmail({
          to: email,
          subject: 'Your Kickoff Verification Code',
          text: `Your verification code is: ${otp}`,
          html: `
            <div style="font-family: sans-serif; padding: 24px; max-width: 480px; margin: 0 auto; border: 1px solid #e9ecef; borderRadius: 12px;">
              <h2 style="color: #1E4D2B; text-align: center;">Welcome to Kickoff!</h2>
              <p>Thank you for signing up. Please verify your email address by entering the following code in the app:</p>
              <div style="background: #f8f9fa; padding: 16px; text-align: center; font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #1E4D2B; margin: 24px 0; border-radius: 8px;">
                ${otp}
              </div>
              <p style="font-size: 13px; color: #6c757d; text-align: center;">This code will expire in 10 minutes.</p>
            </div>
          `,
        });

        return reply.code(200).send({
          success: true,
          message: 'A 6-digit verification code has been queued and sent to your email.',
        });
      } finally {
        dbClient.release();
      }
    }
  );

  /**
   * POST /api/auth/verify-signup-otp
   * Verifies the 6-digit OTP and creates the verified user account in Supabase.
   */
  server.post<{ Body: VerifyOtpBodyType }>(
    '/api/auth/verify-signup-otp',
    { schema: { body: VerifyOtpBody } },
    async (request, reply) => {
      const { email, password, token } = request.body;

      const dbClient = await pool.connect();
      try {
        // 1. Fetch OTP record
        const otpRes = await dbClient.query(
          'SELECT otp, expires_at FROM public.otps WHERE email = $1 AND expires_at > NOW() ORDER BY created_at DESC LIMIT 1',
          [email]
        );

        if (otpRes.rows.length === 0 || otpRes.rows[0].otp !== token) {
          return reply.code(400).send({
            error: {
              code: 'INVALID_OTP',
              message: 'The verification code is invalid or has expired.',
            },
          });
        }

        // 2. Clear verified OTP
        await dbClient.query('DELETE FROM public.otps WHERE email = $1', [email]);

        // 3. Create confirmed user in Supabase Auth via admin interface
        const { data, error } = await supabaseAdmin.auth.admin.createUser({
          email,
          password,
          email_confirm: true, // Auto-confirm verified account
        });

        if (error) {
          server.log.error(error);
          return reply.code(400).send({
            error: {
              code: 'SIGNUP_FAILED',
              message: error.message,
            },
          });
        }

        return reply.code(201).send({
          success: true,
          userId: data.user.id,
        });
      } finally {
        dbClient.release();
      }
    }
  );

  /**
   * POST /api/auth/forgot-password
   * Triggers a password reset email via Supabase Auth.
   * Deliberately returns a non-revealing response (enumeration protection).
   */
  server.post<{ Body: ForgotPasswordBodyType }>(
    '/api/auth/forgot-password',
    { schema: { body: ForgotPasswordBody } },
    async (request, reply) => {
      const { email } = request.body;

      // Fire and forget — don't reveal whether the email exists
      await supabaseAdmin.auth.resetPasswordForEmail(email);

      return reply.code(200).send({
        success: true,
        message: 'If an account exists, a reset email has been sent.',
      });
    }
  );

  /**
   * POST /api/auth/reset-password
   * Completes a password reset using the token from the reset email.
   */
  server.post<{ Body: ResetPasswordBodyType }>(
    '/api/auth/reset-password',
    { schema: { body: ResetPasswordBody } },
    async (request, reply) => {
      const { token, new_password } = request.body;

      const { error } = await supabaseAdmin.auth.admin.updateUserById(
        token, // user_id or reset token identifier
        { password: new_password }
      );

      if (error) {
        return reply.code(400).send({
          error: {
            code: 'INVALID_RESET_TOKEN',
            message: 'The reset token is invalid or has expired.',
          },
        });
      }

      return reply.code(200).send({ success: true });
    }
  );
}
