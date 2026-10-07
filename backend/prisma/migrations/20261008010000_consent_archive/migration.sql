-- Dovezile consimțământului după ștergerea contului (3 ani), fără identificatori direcți
CREATE TABLE "consent_archive" (
    "id" UUID NOT NULL,
    "subject" VARCHAR(64) NOT NULL,
    "purpose" "ConsentPurpose" NOT NULL,
    "policyVersion" VARCHAR(16) NOT NULL,
    "granted" BOOLEAN NOT NULL,
    "at" TIMESTAMP(3) NOT NULL,
    "archivedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "consent_archive_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "consent_archive_archivedAt_idx" ON "consent_archive"("archivedAt");
