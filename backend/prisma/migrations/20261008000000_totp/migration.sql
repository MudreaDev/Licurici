-- Autentificarea în doi pași (TOTP)
ALTER TABLE "users" ADD COLUMN "totpSecret" VARCHAR(64),
ADD COLUMN "totpEnabledAt" TIMESTAMP(3);
