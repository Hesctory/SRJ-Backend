-- =============================================================================
-- backfill_enrollment_debts.sql
-- Generates missing enrollment_debts for all enrollments up to the current date.
--
-- Rules:
--   ADMISSION  (charge_type_id=1) : isnew=true enrollments only, once per enrollment.
--   ENROLLMENT (charge_type_id=2) : every enrollment, once per enrollment.
--   TUITION    (charge_type_id=3) : one row per month, per enrollment.
--                                   Past years  → months 3-12.
--                                   Current year → months 3 through CURRENT_MONTH.
--
-- Status assignment:
--   due_date < today  → 4 (OVERDUE)
--   due_date >= today → 1 (PENDING)
--
-- Idempotent: existing debts are left untouched via NOT EXISTS guards.
-- Safe to re-run without creating duplicates.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. ADMISSION debts (Cuota de Ingreso) — isnew enrollments only
-- ---------------------------------------------------------------------------
INSERT INTO enrollment_debts (
    student_id, enrollment_id, school_year_id,
    charge_type_id, amount, description,
    due_date, period_month, status_id,
    created_at, updated_at
)
SELECT
    e.student_id,
    e.id,
    e.school_year_id,
    1,
    sf.registration_fee,
    'Cuota de Ingreso ' || sy.year::text,
    sym3.due_date,
    NULL,
    CASE WHEN sym3.due_date < CURRENT_DATE THEN 4 ELSE 1 END,
    NOW(),
    NOW()
FROM enrollment e
JOIN school_year sy
    ON sy.id = e.school_year_id
JOIN grade_offering_shift_sections goss
    ON goss.id = e.grade_offering_shift_section_id
JOIN grade_offering_shifts gos
    ON gos.id = goss.grade_offering_shift_id
JOIN grade_offerings go
    ON go.id = gos.grade_offering_id
JOIN grades g
    ON g.id = go.grade_id
JOIN LATERAL (
    SELECT sf2.registration_fee
    FROM school_fee sf2
    WHERE sf2.school_year_id       = e.school_year_id
      AND sf2.level_id             = g.level_id
      AND sf2.shift_id             = gos.shift_id
      AND sf2.school_fee_concept_id = e.school_fee_concept_id
    LIMIT 1
) sf ON true
JOIN school_year_months sym3
    ON sym3.school_year_id = e.school_year_id
   AND sym3.month = 3
WHERE sy.year <= EXTRACT(YEAR FROM CURRENT_DATE)
  AND e.isnew = true
  AND sf.registration_fee > 0
  AND NOT EXISTS (
      SELECT 1
      FROM enrollment_debts ed
      WHERE ed.enrollment_id  = e.id
        AND ed.charge_type_id = 1
  );

-- ---------------------------------------------------------------------------
-- 2. ENROLLMENT debts (Matrícula) — every enrollment, skip if amount is zero
-- ---------------------------------------------------------------------------
INSERT INTO enrollment_debts (
    student_id, enrollment_id, school_year_id,
    charge_type_id, amount, description,
    due_date, period_month, status_id,
    created_at, updated_at
)
SELECT
    e.student_id,
    e.id,
    e.school_year_id,
    2,
    sf.enrollment_price,
    'Matrícula ' || sy.year::text,
    sym3.due_date,
    NULL,
    CASE WHEN sym3.due_date < CURRENT_DATE THEN 4 ELSE 1 END,
    NOW(),
    NOW()
FROM enrollment e
JOIN school_year sy
    ON sy.id = e.school_year_id
JOIN grade_offering_shift_sections goss
    ON goss.id = e.grade_offering_shift_section_id
JOIN grade_offering_shifts gos
    ON gos.id = goss.grade_offering_shift_id
JOIN grade_offerings go
    ON go.id = gos.grade_offering_id
JOIN grades g
    ON g.id = go.grade_id
JOIN LATERAL (
    SELECT sf2.enrollment_price
    FROM school_fee sf2
    WHERE sf2.school_year_id       = e.school_year_id
      AND sf2.level_id             = g.level_id
      AND sf2.shift_id             = gos.shift_id
      AND sf2.school_fee_concept_id = e.school_fee_concept_id
    LIMIT 1
) sf ON true
JOIN school_year_months sym3
    ON sym3.school_year_id = e.school_year_id
   AND sym3.month = 3
WHERE sy.year <= EXTRACT(YEAR FROM CURRENT_DATE)
  AND sf.enrollment_price > 0
  AND NOT EXISTS (
      SELECT 1
      FROM enrollment_debts ed
      WHERE ed.enrollment_id  = e.id
        AND ed.charge_type_id = 2
  );

-- ---------------------------------------------------------------------------
-- 3. TUITION debts (Mensualidad) — one row per eligible month per enrollment
--    Past years:    all months that exist in school_year_months (3-12)
--    Current year:  months up to and including the current calendar month
-- ---------------------------------------------------------------------------
INSERT INTO enrollment_debts (
    student_id, enrollment_id, school_year_id,
    charge_type_id, amount, description,
    due_date, period_month, status_id,
    created_at, updated_at
)
SELECT
    e.student_id,
    e.id,
    e.school_year_id,
    3,
    sf.tuition_cost,
    'Pensión ' || CASE sym.month
        WHEN 3  THEN 'Marzo'
        WHEN 4  THEN 'Abril'
        WHEN 5  THEN 'Mayo'
        WHEN 6  THEN 'Junio'
        WHEN 7  THEN 'Julio'
        WHEN 8  THEN 'Agosto'
        WHEN 9  THEN 'Septiembre'
        WHEN 10 THEN 'Octubre'
        WHEN 11 THEN 'Noviembre'
        WHEN 12 THEN 'Diciembre'
    END || ' - ' || sy.year::text,
    sym.due_date,
    sym.month,
    CASE WHEN sym.due_date < CURRENT_DATE THEN 4 ELSE 1 END,
    NOW(),
    NOW()
FROM enrollment e
JOIN school_year sy
    ON sy.id = e.school_year_id
JOIN grade_offering_shift_sections goss
    ON goss.id = e.grade_offering_shift_section_id
JOIN grade_offering_shifts gos
    ON gos.id = goss.grade_offering_shift_id
JOIN grade_offerings go
    ON go.id = gos.grade_offering_id
JOIN grades g
    ON g.id = go.grade_id
JOIN LATERAL (
    SELECT sf2.tuition_cost
    FROM school_fee sf2
    WHERE sf2.school_year_id       = e.school_year_id
      AND sf2.level_id             = g.level_id
      AND sf2.shift_id             = gos.shift_id
      AND sf2.school_fee_concept_id = e.school_fee_concept_id
    LIMIT 1
) sf ON true
JOIN school_year_months sym
    ON sym.school_year_id = e.school_year_id
WHERE sy.year <= EXTRACT(YEAR FROM CURRENT_DATE)
  AND (
      -- past years: every month defined for the year
      sy.year < EXTRACT(YEAR FROM CURRENT_DATE)
      OR
      -- current year: only months up to (and including) today's month
      (sy.year = EXTRACT(YEAR FROM CURRENT_DATE)
       AND sym.month <= EXTRACT(MONTH FROM CURRENT_DATE))
  )
  AND NOT EXISTS (
      SELECT 1
      FROM enrollment_debts ed
      WHERE ed.enrollment_id  = e.id
        AND ed.charge_type_id = 3
        AND ed.period_month   = sym.month
  );

COMMIT;

-- ---------------------------------------------------------------------------
-- Summary of what was generated (run separately to verify)
-- ---------------------------------------------------------------------------
-- SELECT charge_type_id, COUNT(*) as total, SUM(amount) as total_amount
-- FROM enrollment_debts
-- GROUP BY charge_type_id
-- ORDER BY charge_type_id;
