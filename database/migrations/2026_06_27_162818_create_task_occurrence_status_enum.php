<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement(<<<'SQL'
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_type
                    WHERE typname = 'task_occurrence_status'
                ) THEN
                    CREATE TYPE task_occurrence_status AS ENUM (
                        'pending',
                        'notified',
                        'done',
                        'skipped',
                        'snoozed',
                        'missed',
                        'cancelled',
                        'overridden'
                    );
                END IF;
            END
            $$;
        SQL);
    }

    public function down(): void
    {
        DB::statement(<<<'SQL'
            DO $$
            BEGIN
                IF EXISTS (
                    SELECT 1
                    FROM pg_type
                    WHERE typname = 'task_occurrence_status'
                ) THEN
                    DROP TYPE task_occurrence_status;
                END IF;
            END
            $$;
        SQL);
    }
};