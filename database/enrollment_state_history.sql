-- Enrollment state-transition history.
--
-- Records every change to enrollment.state_id (active -> withdrawn -> restored, etc.)
-- together with when it happened and who performed it, so reports can answer
-- "when was this student withdrawn / restored?". Idempotent: safe to re-run.
--
-- Apply with:  psql "$DATABASE_URL" -f database/enrollment_state_history.sql

CREATE TABLE IF NOT EXISTS public.enrollment_state_history (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enrollment_id integer     NOT NULL REFERENCES public.enrollment(id),
    from_state_id integer         NULL REFERENCES public.enrollment_states(id), -- NULL = initial (on create)
    to_state_id   integer     NOT NULL REFERENCES public.enrollment_states(id),
    changed_at    timestamptz NOT NULL DEFAULT now(),
    changed_by    integer         NULL REFERENCES public.users(id)
);

CREATE INDEX IF NOT EXISTS ix_enrollment_state_history_enrollment
    ON public.enrollment_state_history (enrollment_id);
