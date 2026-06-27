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
                    WHERE typname = 'task_schedule_type'
                ) THEN
                    CREATE TYPE task_schedule_type AS ENUM (
                        'once',
                        'fixed_times',
                        'interval',
                        'specific_dates',
                        'weekly',
                        'monthly',
                        'rrule'
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
                    WHERE typname = 'task_schedule_type'
                ) THEN
                    DROP TYPE task_schedule_type;
                END IF;
            END
            $$;
        SQL);
    }
};