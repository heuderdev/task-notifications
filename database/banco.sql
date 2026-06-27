BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE task_schedule_type AS ENUM (
    'once',
    'fixed_times',
    'interval',
    'specific_dates',
    'weekly',
    'monthly',
    'rrule'
);

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

CREATE TYPE task_action_type AS ENUM (
    'complete',
    'skip',
    'snooze'
);

CREATE TYPE occurrence_override_type AS ENUM (
    'skip',
    'reschedule',
    'replace'
);

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    timezone VARCHAR(64) NOT NULL DEFAULT 'America/Sao_Paulo',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tasks (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    description TEXT NULL,
    priority SMALLINT NOT NULL DEFAULT 0,
    color VARCHAR(20) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    starts_at TIMESTAMPTZ NULL,
    ends_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_tasks_priority CHECK (priority BETWEEN 0 AND 5),
    CONSTRAINT chk_tasks_date_range CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at >= starts_at)
);

CREATE TABLE task_schedules (
    id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    type task_schedule_type NOT NULL,
    timezone VARCHAR(64) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NULL,
    start_time TIME NULL,
    end_time TIME NULL,
    interval_minutes INTEGER NULL,
    day_of_month SMALLINT NULL,
    month_of_year SMALLINT NULL,
    days_of_week JSONB NULL,
    recurrence_rule TEXT NULL,
    generate_ahead_days SMALLINT NOT NULL DEFAULT 7,
    based_on_completion BOOLEAN NOT NULL DEFAULT FALSE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_task_schedules_date_range CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT chk_task_schedules_interval CHECK (interval_minutes IS NULL OR interval_minutes > 0),
    CONSTRAINT chk_task_schedules_day_of_month CHECK (day_of_month IS NULL OR day_of_month BETWEEN 1 AND 31),
    CONSTRAINT chk_task_schedules_month_of_year CHECK (month_of_year IS NULL OR month_of_year BETWEEN 1 AND 12),
    CONSTRAINT chk_task_schedules_time_range CHECK (end_time IS NULL OR start_time IS NULL OR end_time > start_time),
    CONSTRAINT chk_task_schedules_generate_ahead_days CHECK (generate_ahead_days BETWEEN 1 AND 30)
);

CREATE TABLE task_schedule_times (
    id BIGSERIAL PRIMARY KEY,
    task_schedule_id BIGINT NOT NULL REFERENCES task_schedules(id) ON DELETE CASCADE,
    run_time TIME NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (task_schedule_id, run_time)
);

CREATE TABLE task_schedule_specific_dates (
    id BIGSERIAL PRIMARY KEY,
    task_schedule_id BIGINT NOT NULL REFERENCES task_schedules(id) ON DELETE CASCADE,
    run_date DATE NOT NULL,
    run_time TIME NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (task_schedule_id, run_date, run_time)
);

CREATE TABLE task_schedule_exceptions (
    id BIGSERIAL PRIMARY KEY,
    task_schedule_id BIGINT NOT NULL REFERENCES task_schedules(id) ON DELETE CASCADE,
    exception_date DATE NOT NULL,
    reason VARCHAR(255) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (task_schedule_id, exception_date)
);

CREATE TABLE task_schedule_overrides (
    id BIGSERIAL PRIMARY KEY,
    task_schedule_id BIGINT NOT NULL REFERENCES task_schedules(id) ON DELETE CASCADE,
    original_occurrence_at TIMESTAMPTZ NOT NULL,
    override_type occurrence_override_type NOT NULL,
    new_scheduled_for TIMESTAMPTZ NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (task_schedule_id, original_occurrence_at)
);

CREATE TABLE task_occurrences (
    id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    task_schedule_id BIGINT NULL REFERENCES task_schedules(id) ON DELETE SET NULL,
    original_scheduled_for TIMESTAMPTZ NOT NULL,
    scheduled_for TIMESTAMPTZ NOT NULL,
    status task_occurrence_status NOT NULL DEFAULT 'pending',
    notification_sent_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,
    skipped_at TIMESTAMPTZ NULL,
    snoozed_until TIMESTAMPTZ NULL,
    cancelled_at TIMESTAMPTZ NULL,
    missed_at TIMESTAMPTZ NULL,
    notes TEXT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_task_occurrences_unique_run UNIQUE (task_id, scheduled_for),
    CONSTRAINT chk_task_occurrences_done CHECK (status <> 'done' OR completed_at IS NOT NULL),
    CONSTRAINT chk_task_occurrences_skipped CHECK (status <> 'skipped' OR skipped_at IS NOT NULL),
    CONSTRAINT chk_task_occurrences_snoozed CHECK (status <> 'snoozed' OR snoozed_until IS NOT NULL),
    CONSTRAINT chk_task_occurrences_cancelled CHECK (status <> 'cancelled' OR cancelled_at IS NOT NULL),
    CONSTRAINT chk_task_occurrences_missed CHECK (status <> 'missed' OR missed_at IS NOT NULL)
);

CREATE TABLE task_occurrence_actions (
    id BIGSERIAL PRIMARY KEY,
    task_occurrence_id BIGINT NOT NULL REFERENCES task_occurrences(id) ON DELETE CASCADE,
    action task_action_type NOT NULL,
    token_hash CHAR(64) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ NULL,
    used_ip INET NULL,
    used_user_agent TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_task_occurrence_actions_token_hash UNIQUE (token_hash),
    CONSTRAINT chk_task_occurrence_actions_expiry CHECK (expires_at > created_at),
    CONSTRAINT chk_task_occurrence_actions_used_at CHECK (used_at IS NULL OR used_at >= created_at)
);

CREATE TABLE task_logs (
    id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    task_occurrence_id BIGINT NULL REFERENCES task_occurrences(id) ON DELETE SET NULL,
    event_name VARCHAR(100) NOT NULL,
    event_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tasks_user_active ON tasks (user_id, is_active);
CREATE INDEX idx_task_schedules_task_active ON task_schedules (task_id, is_active);
CREATE INDEX idx_task_schedules_type ON task_schedules (type);
CREATE INDEX idx_task_schedules_active_dates ON task_schedules (is_active, start_date, end_date);
CREATE INDEX idx_task_occurrences_status_schedule ON task_occurrences (status, scheduled_for);
CREATE INDEX idx_task_occurrences_task_schedule ON task_occurrences (task_id, task_schedule_id);
CREATE INDEX idx_task_occurrences_notification_sent_at ON task_occurrences (notification_sent_at);
CREATE INDEX idx_task_occurrences_original_scheduled_for ON task_occurrences (original_scheduled_for);
CREATE INDEX idx_task_occurrence_actions_occurrence_action ON task_occurrence_actions (task_occurrence_id, action);
CREATE INDEX idx_task_occurrence_actions_expires_at ON task_occurrence_actions (expires_at);
CREATE INDEX idx_task_logs_task_created_at ON task_logs (task_id, created_at DESC);
CREATE INDEX idx_task_logs_occurrence_created_at ON task_logs (task_occurrence_id, created_at DESC);
CREATE INDEX idx_task_schedule_specific_dates_date ON task_schedule_specific_dates (run_date);
CREATE INDEX idx_task_schedule_exceptions_date ON task_schedule_exceptions (exception_date);
CREATE INDEX idx_task_schedule_overrides_original ON task_schedule_overrides (task_schedule_id, original_occurrence_at);

COMMENT ON TABLE tasks IS 'Cadastro principal da tarefa do usuario.';
COMMENT ON TABLE task_schedules IS 'Regras de recorrencia e agendamento da tarefa.';
COMMENT ON TABLE task_schedule_times IS 'Horarios fixos vinculados a schedules do tipo fixed_times.';
COMMENT ON TABLE task_schedule_specific_dates IS 'Datas especificas escolhidas manualmente.';
COMMENT ON TABLE task_schedule_exceptions IS 'Datas em que a recorrencia nao deve gerar ocorrencia.';
COMMENT ON TABLE task_schedule_overrides IS 'Alteracoes pontuais sobre ocorrencias especificas.';
COMMENT ON TABLE task_occurrences IS 'Instancias reais que serao notificadas e marcadas como executadas.';
COMMENT ON TABLE task_occurrence_actions IS 'Links unicos de acao para cada ocorrencia.';
COMMENT ON TABLE task_logs IS 'Auditoria de eventos relacionados a tarefa e suas ocorrencias.';

COMMIT;