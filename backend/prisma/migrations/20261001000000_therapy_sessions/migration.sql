-- AlterEnum
ALTER TYPE "ConsentPurpose" ADD VALUE 'AI_SUMMARY';

-- CreateTable
CREATE TABLE "therapy_sessions" (
    "id" UUID NOT NULL,
    "childId" UUID NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL,
    "endedAt" TIMESTAMP(3) NOT NULL,
    "moodBefore" VARCHAR(16),
    "moodAfter" VARCHAR(16),
    "record" JSONB NOT NULL,
    "facts" JSONB NOT NULL,
    "receivedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "therapy_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "session_summaries" (
    "sessionId" UUID NOT NULL,
    "model" VARCHAR(40) NOT NULL,
    "content" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "session_summaries_pkey" PRIMARY KEY ("sessionId")
);

-- CreateIndex
CREATE INDEX "therapy_sessions_childId_startedAt_idx" ON "therapy_sessions"("childId", "startedAt");

-- AddForeignKey
ALTER TABLE "therapy_sessions" ADD CONSTRAINT "therapy_sessions_childId_fkey" FOREIGN KEY ("childId") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "session_summaries" ADD CONSTRAINT "session_summaries_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "therapy_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

