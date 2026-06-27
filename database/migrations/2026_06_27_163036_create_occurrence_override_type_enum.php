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
                    WHERE typname = 'occurrence_override_type'
                ) THEN
                    CREATE TYPE occurrence_override_type AS ENUM (
                        'skip',
                        'reschedule',
                        'replace'
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
                    WHERE typname = 'occurrence_override_type'
                ) THEN
                    DROP TYPE occurrence_override_type;
                END IF;
            END
            $$;
        SQL);
    }
};