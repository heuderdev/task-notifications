<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tasks', function (Blueprint $table) {
            $table->comment('Cadastro principal da tarefa do usuario.');

            $table->id();
            $table->foreignId('user_id')
                ->constrained('users')
                ->cascadeOnDelete();

            $table->string('name', 150);
            $table->text('description')->nullable();
            $table->unsignedSmallInteger('priority')->default(0);
            $table->string('color', 20)->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestampTz('starts_at')->nullable();
            $table->timestampTz('ends_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'is_active'], 'idx_tasks_user_active');
        });

        DB::statement("
            ALTER TABLE tasks
            ADD CONSTRAINT chk_tasks_priority
            CHECK (priority BETWEEN 0 AND 5)
        ");

        DB::statement("
            ALTER TABLE tasks
            ADD CONSTRAINT chk_tasks_date_range
            CHECK (
                ends_at IS NULL
                OR starts_at IS NULL
                OR ends_at >= starts_at
            )
        ");
    }

    public function down(): void
    {
        Schema::dropIfExists('tasks');
    }
};