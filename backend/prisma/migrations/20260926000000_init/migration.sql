-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "Role" AS ENUM ('PARENT', 'THERAPIST', 'ADMIN');

-- CreateEnum
CREATE TYPE "GradeCode" AS ENUM ('GRADINITA', 'CLASA1', 'CLASA2', 'CLASA3', 'CLASA4');

-- CreateEnum
CREATE TYPE "ConsentPurpose" AS ENUM ('SYNC', 'WEEKLY_REPORT', 'THERAPIST_SHARING', 'PUSH_NOTIFICATIONS');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT,
    "role" "Role" NOT NULL DEFAULT 'PARENT',
    "locale" TEXT NOT NULL DEFAULT 'ro',
    "verifiedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "children" (
    "id" UUID NOT NULL,
    "parentId" UUID NOT NULL,
    "nickname" VARCHAR(40) NOT NULL,
    "avatar" VARCHAR(16) NOT NULL,
    "birthYear" SMALLINT,
    "grade" "GradeCode" NOT NULL DEFAULT 'CLASA1',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "children_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "consents" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "purpose" "ConsentPurpose" NOT NULL,
    "policyVersion" VARCHAR(16) NOT NULL,
    "granted" BOOLEAN NOT NULL,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ipHash" VARCHAR(64),

    CONSTRAINT "consents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "devices" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "platform" VARCHAR(16) NOT NULL,
    "pushToken" TEXT,
    "lastSeen" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "devices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "child_settings" (
    "childId" UUID NOT NULL,
    "calmMode" BOOLEAN NOT NULL DEFAULT false,
    "reduceMotion" BOOLEAN NOT NULL DEFAULT false,
    "musicVol" DOUBLE PRECISION NOT NULL DEFAULT 0.5,
    "sfxVol" DOUBLE PRECISION NOT NULL DEFAULT 0.5,
    "voiceVol" DOUBLE PRECISION NOT NULL DEFAULT 0.5,
    "extra" JSONB NOT NULL DEFAULT '{}',
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "child_settings_pkey" PRIMARY KEY ("childId")
);

-- CreateTable
CREATE TABLE "game_sessions" (
    "id" UUID NOT NULL,
    "childId" UUID NOT NULL,
    "gameId" VARCHAR(40) NOT NULL,
    "tier" SMALLINT NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL,
    "durationSec" INTEGER NOT NULL,
    "stars" SMALLINT NOT NULL,

    CONSTRAINT "game_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "game_events" (
    "id" UUID NOT NULL,
    "sessionId" UUID NOT NULL,
    "type" VARCHAR(32) NOT NULL,
    "skill" VARCHAR(40),
    "correct" BOOLEAN,
    "firstTry" BOOLEAN,
    "payload" JSONB NOT NULL DEFAULT '{}',
    "at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "game_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "child_skill_stats" (
    "childId" UUID NOT NULL,
    "skill" VARCHAR(40) NOT NULL,
    "attempts" INTEGER NOT NULL,
    "firstTry" INTEGER NOT NULL,
    "accuracy" DOUBLE PRECISION NOT NULL,
    "lastPlayed" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "child_skill_stats_pkey" PRIMARY KEY ("childId","skill")
);

-- CreateTable
CREATE TABLE "adventure_progress" (
    "childId" UUID NOT NULL,
    "level" INTEGER NOT NULL DEFAULT 1,
    "stars" JSONB NOT NULL DEFAULT '{}',
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "adventure_progress_pkey" PRIMARY KEY ("childId")
);

-- CreateTable
CREATE TABLE "care_links" (
    "childId" UUID NOT NULL,
    "therapistId" UUID NOT NULL,
    "scope" VARCHAR(32) NOT NULL DEFAULT 'stats:read',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3),

    CONSTRAINT "care_links_pkey" PRIMARY KEY ("childId","therapistId")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL,
    "actorId" UUID NOT NULL,
    "action" VARCHAR(48) NOT NULL,
    "targetId" UUID,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "children_parentId_idx" ON "children"("parentId");

-- CreateIndex
CREATE INDEX "consents_userId_purpose_at_idx" ON "consents"("userId", "purpose", "at");

-- CreateIndex
CREATE INDEX "devices_userId_idx" ON "devices"("userId");

-- CreateIndex
CREATE INDEX "game_sessions_childId_startedAt_idx" ON "game_sessions"("childId", "startedAt");

-- CreateIndex
CREATE INDEX "game_events_sessionId_idx" ON "game_events"("sessionId");

-- CreateIndex
CREATE INDEX "game_events_at_idx" ON "game_events"("at");

-- CreateIndex
CREATE INDEX "audit_logs_actorId_at_idx" ON "audit_logs"("actorId", "at");

-- AddForeignKey
ALTER TABLE "children" ADD CONSTRAINT "children_parentId_fkey" FOREIGN KEY ("parentId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "consents" ADD CONSTRAINT "consents_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "devices" ADD CONSTRAINT "devices_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_settings" ADD CONSTRAINT "child_settings_childId_fkey" FOREIGN KEY ("childId") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "game_sessions" ADD CONSTRAINT "game_sessions_childId_fkey" FOREIGN KEY ("childId") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "game_events" ADD CONSTRAINT "game_events_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "game_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_skill_stats" ADD CONSTRAINT "child_skill_stats_childId_fkey" FOREIGN KEY ("childId") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "adventure_progress" ADD CONSTRAINT "adventure_progress_childId_fkey" FOREIGN KEY ("childId") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "care_links" ADD CONSTRAINT "care_links_childId_fkey" FOREIGN KEY ("childId") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "care_links" ADD CONSTRAINT "care_links_therapistId_fkey" FOREIGN KEY ("therapistId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

