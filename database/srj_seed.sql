--
-- PostgreSQL database dump
--

\restrict 9fOntZCfVe1BKNf8NbYWqAwjzRFhABhEbQxePFGWjdoZtLjCCPCHm10PCyj6kWR

-- Dumped from database version 18.3 (Ubuntu 18.3-1.pgdg22.04+1)
-- Dumped by pg_dump version 18.3 (Ubuntu 18.3-1.pgdg22.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: calc_ubigeo_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calc_ubigeo_code() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    dept_code CHAR(2);
    prov_code CHAR(2);
    dist_code CHAR(2);
BEGIN
    -- Obtener los códigos de las tablas relacionadas
    SELECT d.code, p.code, dist.code 
    INTO dept_code, prov_code, dist_code
    FROM district dist
    JOIN province p ON dist.province_id = p.id
    JOIN department d ON p.department_id = d.id
    WHERE dist.id = NEW.district_id;
    
    -- Concatenar y asignar
    NEW.code := dept_code || prov_code || dist_code;
    
    RETURN NEW;
END;
$$;


--
-- Name: check_admission_uniqueness(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_admission_uniqueness() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_admission_type_id SMALLINT;
    v_existing_count    INTEGER;
BEGIN
    SELECT id INTO v_admission_type_id
    FROM   public.charge_types WHERE code = 'ADMISSION';

    IF NEW.charge_type_id != v_admission_type_id THEN
        RETURN NEW;
    END IF;

    SELECT COUNT(*) INTO v_existing_count
    FROM   public.enrollment_debts
    WHERE  student_id     = NEW.student_id
      AND  charge_type_id = v_admission_type_id
      AND  id            != COALESCE(NEW.id, -1);

    IF v_existing_count > 0 THEN
        RAISE EXCEPTION
            'Student % already has an ADMISSION (Matrícula de Ingreso) debt. '
            'This charge is applied only once per student lifetime.',
            NEW.student_id
        USING ERRCODE = 'unique_violation';
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: check_allocation_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_allocation_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_debt                  public.enrollment_debts%ROWTYPE;
    v_paid_status_id        SMALLINT;
    v_cancelled_status_id   SMALLINT;
    v_total_already_applied NUMERIC(10,2);
    v_available             NUMERIC(10,2);
BEGIN
    SELECT * INTO v_debt FROM public.enrollment_debts WHERE id = NEW.debt_id;
    SELECT id INTO v_paid_status_id      FROM public.debt_statuses WHERE code = 'PAID';
    SELECT id INTO v_cancelled_status_id FROM public.debt_statuses WHERE code = 'CANCELLED';

	RAISE NOTICE 'paid: %, cancelled: %, debt status: %',
	    v_paid_status_id,
	    v_cancelled_status_id,
	    v_debt.status_id;
	
    -- Block allocations against terminal debts.
    IF v_debt.status_id IN (v_paid_status_id, v_cancelled_status_id) THEN
        RAISE EXCEPTION
            'Cannot allocate payment to debt % — debt is in terminal status (PAID or CANCELLED).',
            NEW.debt_id
        USING ERRCODE = 'check_violation';
    END IF;

    -- Block allocations that use a voided payment.
    IF (SELECT is_voided FROM public.payments WHERE id = NEW.payment_id) THEN
        RAISE EXCEPTION
            'Cannot use voided payment % in an allocation.',
            NEW.payment_id
        USING ERRCODE = 'check_violation';
    END IF;

    -- Calculate the amount already allocated to this debt by OTHER allocations.
    -- On UPDATE, exclude the current row's previous value from the sum.
    SELECT COALESCE(SUM(amount_applied), 0)
    INTO   v_total_already_applied
    FROM   public.payment_debt_allocations
    WHERE  debt_id = NEW.debt_id
      AND  id     != COALESCE(NEW.id, -1);

    v_available := v_debt.amount - v_total_already_applied;

    IF NEW.amount_applied > v_available THEN
        RAISE EXCEPTION
            'Allocation of % exceeds available balance of % for debt %. '
            'Total already applied: %, Debt total: %.',
            NEW.amount_applied, v_available, NEW.debt_id,
            v_total_already_applied, v_debt.amount
        USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: check_debt_school_year_consistency(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_debt_school_year_consistency() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_enrollment_school_year_id INTEGER;
BEGIN
    SELECT school_year_id INTO v_enrollment_school_year_id
    FROM   public.enrollment
    WHERE  id = NEW.enrollment_id;

    IF NEW.school_year_id != v_enrollment_school_year_id THEN
        RAISE EXCEPTION
            'enrollment_debts.school_year_id (%) does not match '
            'enrollment.school_year_id (%) for enrollment %.',
            NEW.school_year_id, v_enrollment_school_year_id, NEW.enrollment_id
        USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: check_section_count_integrity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_section_count_integrity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  expected_sections integer;
BEGIN
  -- Obtener el número esperado de secciones desde grade_offering_shifts
  SELECT sections INTO expected_sections
  FROM grade_offering_shifts
  WHERE id = NEW.grade_offering_shift_id;
  
  -- Verificar que no exceda el límite
  IF expected_sections IS NOT NULL THEN
    IF (SELECT COUNT(*) FROM grade_offering_shift_sections 
        WHERE grade_offering_shift_id = NEW.grade_offering_shift_id) > expected_sections THEN
      RAISE EXCEPTION 'Cannot insert more than % sections for shift %', 
        expected_sections, NEW.grade_offering_shift_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;


--
-- Name: enrollment_unique_per_year(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enrollment_unique_per_year() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_year_id integer;
BEGIN
    IF NEW.student_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT go.school_year_id
      INTO v_year_id
      FROM grade_offering_shift_sections sec
      JOIN grade_offering_shifts gos ON gos.id = sec.grade_offering_shift_id
      JOIN grade_offerings go         ON go.id  = gos.grade_offering_id
     WHERE sec.id = NEW.grade_offering_shift_section_id;

    IF EXISTS (
        SELECT 1
          FROM enrollment e
          JOIN grade_offering_shift_sections sec ON sec.id = e.grade_offering_shift_section_id
          JOIN grade_offering_shifts gos         ON gos.id = sec.grade_offering_shift_id
          JOIN grade_offerings go                ON go.id  = gos.grade_offering_id
         WHERE e.student_id = NEW.student_id
           AND go.school_year_id = v_year_id
           AND e.id <> COALESCE(NEW.id, -1)
    ) THEN
        RAISE EXCEPTION 'YEAR_ALREADY_ENROLLED'
            USING ERRCODE = '23505';  -- unique_violation
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: recalculate_debt_status(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.recalculate_debt_status(p_debt_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_debt              public.enrollment_debts%ROWTYPE;
    v_total_paid        NUMERIC(10,2);
    v_new_status_code   VARCHAR(20);
    v_new_status_id     SMALLINT;
    v_cancelled_id      SMALLINT;
BEGIN
    SELECT * INTO v_debt FROM public.enrollment_debts WHERE id = p_debt_id;

    SELECT id INTO v_cancelled_id FROM public.debt_statuses WHERE code = 'CANCELLED';

    -- Never overwrite a CANCELLED debt's status automatically.
    IF v_debt.status_id = v_cancelled_id THEN
        RETURN;
    END IF;

    -- Sum only the amount from non-voided payments.
    SELECT COALESCE(SUM(a.amount_applied), 0) INTO v_total_paid
    FROM   public.payment_debt_allocations a
    JOIN   public.payments p ON p.id = a.payment_id
    WHERE  a.debt_id   = p_debt_id
      AND  p.is_voided = FALSE;

    -- Determine new status.
    IF v_total_paid >= v_debt.amount THEN
        v_new_status_code := 'PAID';
    ELSIF v_total_paid > 0 THEN
        v_new_status_code := 'PARTIALLY_PAID';
    ELSIF v_debt.due_date < CURRENT_DATE THEN
        v_new_status_code := 'OVERDUE';
    ELSE
        v_new_status_code := 'PENDING';
    END IF;

    SELECT id INTO v_new_status_id FROM public.debt_statuses WHERE code = v_new_status_code;

    UPDATE public.enrollment_debts
    SET    status_id  = v_new_status_id,
           updated_at = NOW()
    WHERE  id = p_debt_id;
END;
$$;


--
-- Name: set_student_debts_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_student_debts_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_debt_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_debt_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_debt_id BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_debt_id := OLD.debt_id;
    ELSE
        v_debt_id := NEW.debt_id;
    END IF;

    PERFORM public.recalculate_debt_status(v_debt_id);

    IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$$;


--
-- Name: update_overdue_debts(); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.update_overdue_debts()
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_pending_id  SMALLINT;
    v_partial_id  SMALLINT;
    v_overdue_id  SMALLINT;
    v_count       INTEGER;
BEGIN
    SELECT id INTO v_pending_id FROM public.debt_statuses WHERE code = 'PENDING';
    SELECT id INTO v_partial_id FROM public.debt_statuses WHERE code = 'PARTIALLY_PAID';
    SELECT id INTO v_overdue_id FROM public.debt_statuses WHERE code = 'OVERDUE';

    UPDATE public.enrollment_debts
    SET    status_id  = v_overdue_id,
           updated_at = NOW()
    WHERE  due_date  < CURRENT_DATE
      AND  status_id IN (v_pending_id, v_partial_id);

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'update_overdue_debts: % debts marked as OVERDUE.', v_count;
END;
$$;


--
-- Name: void_payment(integer, integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.void_payment(IN p_payment_id integer, IN p_voided_by integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_debt_id BIGINT;
BEGIN
    UPDATE public.payments
    SET    is_voided = TRUE,
           voided_at = NOW(),
           voided_by = p_voided_by
    WHERE  id       = p_payment_id
      AND  is_voided = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Payment % was not found or is already voided.',
            p_payment_id;
    END IF;

    -- Recalculate status for every debt that this payment touched.
    FOR v_debt_id IN
        SELECT DISTINCT debt_id
        FROM   public.payment_debt_allocations
        WHERE  payment_id = p_payment_id
    LOOP
        PERFORM public.recalculate_debt_status(v_debt_id);
    END LOOP;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: grades; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grades (
    id integer CONSTRAINT academic_grades_id_not_null NOT NULL,
    level_id integer CONSTRAINT academic_grades_level_id_not_null NOT NULL,
    name character varying(50) CONSTRAINT academic_grades_name_not_null NOT NULL,
    year integer CONSTRAINT academic_grades_year_not_null NOT NULL
);


--
-- Name: academic_grades_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.academic_grades_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: academic_grades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.academic_grades_id_seq OWNED BY public.grades.id;


--
-- Name: levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.levels (
    id integer CONSTRAINT academic_levels_id_not_null NOT NULL,
    name character varying(50) CONSTRAINT academic_levels_name_not_null NOT NULL,
    order_index integer CONSTRAINT academic_levels_order_index_not_null NOT NULL
);


--
-- Name: academic_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.academic_levels_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: academic_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.academic_levels_id_seq OWNED BY public.levels.id;


--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id integer NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    parent_account_id integer,
    print_code character varying(30)
);


--
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.accounts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id integer NOT NULL,
    event_type character varying(200),
    event_data jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_log_id_seq OWNED BY public.audit_log.id;


--
-- Name: charge_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.charge_types (
    id smallint NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: charge_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.charge_types ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.charge_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: childbirth_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.childbirth_type (
    id integer NOT NULL,
    name character varying(50)
);


--
-- Name: childbirth_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.childbirth_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: childbirth_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.childbirth_type_id_seq OWNED BY public.childbirth_type.id;


--
-- Name: civil_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.civil_state (
    id integer NOT NULL,
    name character varying(40) NOT NULL
);


--
-- Name: civil_state_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.civil_state_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: civil_state_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.civil_state_id_seq OWNED BY public.civil_state.id;


--
-- Name: debt_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.debt_statuses (
    id smallint NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    is_terminal boolean DEFAULT false NOT NULL
);


--
-- Name: debt_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.debt_statuses ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.debt_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: department; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.department (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    code character(2) NOT NULL
);


--
-- Name: department_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.department_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: department_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.department_id_seq OWNED BY public.department.id;


--
-- Name: disabilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.disabilities (
    student_id integer NOT NULL,
    has_disability_certificate boolean NOT NULL,
    disability_certificate_number character varying(50),
    disability_type_id integer,
    disability_degree_id integer
);


--
-- Name: disability_degrees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.disability_degrees (
    id integer NOT NULL,
    degree character varying(30) NOT NULL
);


--
-- Name: disability_degrees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.disability_degrees_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: disability_degrees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.disability_degrees_id_seq OWNED BY public.disability_degrees.id;


--
-- Name: disability_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.disability_types (
    id integer NOT NULL,
    type character varying(40) NOT NULL
);


--
-- Name: disability_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.disability_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: disability_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.disability_types_id_seq OWNED BY public.disability_types.id;


--
-- Name: district; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.district (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    province_id integer NOT NULL,
    code character(2) NOT NULL
);


--
-- Name: district_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.district_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: district_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.district_id_seq OWNED BY public.district.id;


--
-- Name: document_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_types (
    id integer NOT NULL,
    name character varying(30) NOT NULL
);


--
-- Name: document_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.document_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.document_types_id_seq OWNED BY public.document_types.id;


--
-- Name: employment_contract; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employment_contract (
    id integer NOT NULL,
    staff_member_id integer NOT NULL,
    institution_id integer NOT NULL,
    school_year_id integer NOT NULL,
    job_position_id integer NOT NULL,
    area_id integer,
    start_date date NOT NULL,
    end_date date,
    salary numeric(10,2),
    CONSTRAINT employment_contract_dates_check CHECK (((end_date IS NULL) OR (end_date >= start_date))),
    CONSTRAINT employment_contract_salary_check CHECK (((salary IS NULL) OR (salary >= (0)::numeric)))
);


--
-- Name: employment_contract_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.employment_contract_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employment_contract_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.employment_contract_id_seq OWNED BY public.employment_contract.id;


--
-- Name: enrollment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enrollment (
    id integer NOT NULL,
    code character(11) NOT NULL,
    code_number integer NOT NULL,
    grade_offering_shift_section_id integer NOT NULL,
    student_id integer NOT NULL,
    school_fee_concept_id integer NOT NULL,
    previous_school text,
    school_year_id integer NOT NULL,
    enrollment_date date DEFAULT CURRENT_DATE,
    state_id integer DEFAULT 1 NOT NULL,
    isnew boolean DEFAULT false NOT NULL
);


--
-- Name: enrollment_debts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enrollment_debts (
    id bigint CONSTRAINT student_debts_id_not_null NOT NULL,
    student_id integer CONSTRAINT student_debts_student_id_not_null NOT NULL,
    enrollment_id integer CONSTRAINT student_debts_enrollment_id_not_null NOT NULL,
    school_year_id integer CONSTRAINT student_debts_school_year_id_not_null NOT NULL,
    charge_type_id smallint CONSTRAINT student_debts_charge_type_id_not_null NOT NULL,
    amount numeric(10,2) CONSTRAINT student_debts_amount_not_null NOT NULL,
    description text,
    due_date date CONSTRAINT student_debts_due_date_not_null NOT NULL,
    period_month smallint,
    status_id smallint CONSTRAINT student_debts_status_id_not_null NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() CONSTRAINT student_debts_created_at_not_null NOT NULL,
    updated_at timestamp with time zone DEFAULT now() CONSTRAINT student_debts_updated_at_not_null NOT NULL,
    created_by integer,
    CONSTRAINT chk_period_tuition_only CHECK ((((charge_type_id = 3) AND (period_month IS NOT NULL)) OR ((charge_type_id <> 3) AND (period_month IS NULL)))),
    CONSTRAINT enrollment_debts_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT student_debts_period_month_check CHECK (((period_month >= 1) AND (period_month <= 12)))
);


--
-- Name: enrollment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enrollment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enrollment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enrollment_id_seq OWNED BY public.enrollment.id;


--
-- Name: enrollment_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enrollment_states (
    id integer NOT NULL,
    name character varying(20)
);


--
-- Name: enrollment_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enrollment_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enrollment_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enrollment_states_id_seq OWNED BY public.enrollment_states.id;


--
-- Name: ethnic_self_identifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ethnic_self_identifications (
    id integer NOT NULL,
    ethnic_self_identification character varying(100) NOT NULL
);


--
-- Name: ethnic_self_identifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ethnic_self_identifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ethnic_self_identifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ethnic_self_identifications_id_seq OWNED BY public.ethnic_self_identifications.id;


--
-- Name: familiar_relationship_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.familiar_relationship_type (
    id integer NOT NULL,
    name character varying(100) NOT NULL
);


--
-- Name: familiar_relationship_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.familiar_relationship_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: familiar_relationship_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.familiar_relationship_type_id_seq OWNED BY public.familiar_relationship_type.id;


--
-- Name: familiar_student_relationship; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.familiar_student_relationship (
    id integer NOT NULL,
    familiar_id integer NOT NULL,
    student_id integer NOT NULL,
    lives_together boolean NOT NULL,
    familiar_relationship_type_id integer CONSTRAINT familiar_student_relationsh_familiar_relationship_type_not_null NOT NULL,
    isguardian boolean NOT NULL
);


--
-- Name: familiar_student_relationship_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.familiar_student_relationship_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: familiar_student_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.familiar_student_relationship_id_seq OWNED BY public.familiar_student_relationship.id;


--
-- Name: familiars; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.familiars (
    person_id integer NOT NULL,
    level_of_education_id integer,
    occupation character varying(70),
    workplace character varying(100),
    lives boolean NOT NULL
);


--
-- Name: genders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.genders (
    id integer NOT NULL,
    name character varying(50) NOT NULL
);


--
-- Name: genders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.genders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: genders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.genders_id_seq OWNED BY public.genders.id;


--
-- Name: grade_offering_shift_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grade_offering_shift_sections (
    id integer NOT NULL,
    grade_offering_shift_id integer NOT NULL,
    section character(1),
    section_number smallint,
    CONSTRAINT grade_offering_shift_sections_section_check CHECK ((section = ANY (ARRAY['A'::bpchar, 'B'::bpchar, 'C'::bpchar, 'D'::bpchar, 'E'::bpchar, 'F'::bpchar, 'G'::bpchar, 'H'::bpchar, 'I'::bpchar])))
);


--
-- Name: grade_offering_shift_sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.grade_offering_shift_sections_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: grade_offering_shift_sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.grade_offering_shift_sections_id_seq OWNED BY public.grade_offering_shift_sections.id;


--
-- Name: grade_offering_shifts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grade_offering_shifts (
    id integer NOT NULL,
    grade_offering_id integer NOT NULL,
    sections smallint,
    shift_id integer NOT NULL
);


--
-- Name: grade_offering_shifts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.grade_offering_shifts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: grade_offering_shifts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.grade_offering_shifts_id_seq OWNED BY public.grade_offering_shifts.id;


--
-- Name: grade_offerings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grade_offerings (
    id integer NOT NULL,
    grade_id integer NOT NULL,
    school_year_id integer NOT NULL
);


--
-- Name: grade_offerings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.grade_offerings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: grade_offerings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.grade_offerings_id_seq OWNED BY public.grade_offerings.id;


--
-- Name: institution; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.institution (
    id integer NOT NULL,
    name character varying(70) NOT NULL,
    ruc character(11) NOT NULL,
    ruc_state_id integer NOT NULL
);


--
-- Name: institution_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.institution_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: institution_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.institution_id_seq OWNED BY public.institution.id;


--
-- Name: institution_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.institution_levels (
    level_id integer NOT NULL,
    institution_id integer NOT NULL,
    is_active boolean NOT NULL,
    start_date date NOT NULL,
    end_date date
);


--
-- Name: job_positions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_positions (
    id integer NOT NULL,
    name character varying(200) NOT NULL
);


--
-- Name: job_positions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.job_positions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: job_positions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.job_positions_id_seq OWNED BY public.job_positions.id;


--
-- Name: languages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.languages (
    id integer NOT NULL,
    name character varying(59)
);


--
-- Name: languages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.languages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: languages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.languages_id_seq OWNED BY public.languages.id;


--
-- Name: level_of_education; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.level_of_education (
    id integer NOT NULL,
    name character varying(40) NOT NULL
);


--
-- Name: level_of_education_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.level_of_education_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: level_of_education_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.level_of_education_id_seq OWNED BY public.level_of_education.id;


--
-- Name: lunch_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lunch_assignments (
    id integer NOT NULL,
    enrollment_id integer,
    person_id integer NOT NULL,
    lunch_id integer NOT NULL,
    assigned_date date NOT NULL,
    unit_price numeric(10,2) NOT NULL,
    assigned_by_id integer,
    has_debt boolean DEFAULT false NOT NULL,
    is_settled boolean DEFAULT false NOT NULL,
    debt_paid_amount numeric(10,2),
    debt_paid_date date,
    shift_id integer DEFAULT 1 NOT NULL,
    CONSTRAINT lunch_assignments_subject_check CHECK (((enrollment_id IS NOT NULL) OR (person_id IS NOT NULL))),
    CONSTRAINT lunch_assignments_unit_price_check CHECK ((unit_price >= (0)::numeric))
);


--
-- Name: lunch_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.lunch_assignments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: lunch_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.lunch_assignments_id_seq OWNED BY public.lunch_assignments.id;


--
-- Name: lunch_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lunch_categories (
    id integer NOT NULL,
    name character varying(50) NOT NULL
);


--
-- Name: lunch_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.lunch_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: lunch_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.lunch_categories_id_seq OWNED BY public.lunch_categories.id;


--
-- Name: lunches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lunches (
    id integer NOT NULL,
    lunch_category_id integer NOT NULL,
    lunch_name character varying(100),
    cost_price numeric(10,2),
    sale_price numeric(10,2),
    comment text
);


--
-- Name: lunches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.lunches_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: lunches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.lunches_id_seq OWNED BY public.lunches.id;


--
-- Name: payment_debt_allocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_debt_allocations (
    id bigint NOT NULL,
    payment_id integer NOT NULL,
    debt_id bigint NOT NULL,
    amount_applied numeric(10,2) NOT NULL,
    allocated_at timestamp with time zone DEFAULT now() NOT NULL,
    notes text,
    CONSTRAINT payment_debt_allocations_amount_applied_check CHECK ((amount_applied > (0)::numeric))
);


--
-- Name: payment_debt_allocations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.payment_debt_allocations ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.payment_debt_allocations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: payment_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_methods (
    id integer NOT NULL,
    name character varying(50) NOT NULL
);


--
-- Name: payment_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_methods_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_methods_id_seq OWNED BY public.payment_methods.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id integer NOT NULL,
    payment_date date NOT NULL,
    amount numeric(10,2),
    payment_method_id integer NOT NULL,
    n_operation character varying(20),
    created_by integer,
    notes text,
    is_voided boolean DEFAULT false NOT NULL,
    voided_at timestamp with time zone,
    voided_by integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_payment_void_consistency CHECK ((((is_voided = false) AND (voided_at IS NULL) AND (voided_by IS NULL)) OR ((is_voided = true) AND (voided_at IS NOT NULL) AND (voided_by IS NOT NULL))))
);


--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    id integer NOT NULL,
    name character varying(30) NOT NULL
);


--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- Name: person; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.person (
    id integer NOT NULL,
    names character varying(100) NOT NULL,
    paternal_lastname character varying(40) NOT NULL,
    maternal_lastname character varying(40) NOT NULL,
    gender_id integer NOT NULL,
    birth_date date NOT NULL,
    document_type_id integer NOT NULL,
    id_document_number character varying(20) NOT NULL,
    address text NOT NULL,
    address_ubigeo_id integer NOT NULL,
    email character varying(100),
    landline_phone character varying(20),
    cell_phone character varying(20),
    civil_state_id integer,
    religion_id integer,
    ethnic_self_identification_id integer,
    native_language_id integer
);


--
-- Name: person_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.person_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: person_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.person_id_seq OWNED BY public.person.id;


--
-- Name: province; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.province (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    department_id integer NOT NULL,
    code character(2) NOT NULL
);


--
-- Name: province_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.province_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: province_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.province_id_seq OWNED BY public.province.id;


--
-- Name: religion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.religion (
    id integer NOT NULL,
    name character varying(40) NOT NULL
);


--
-- Name: religion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.religion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: religion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.religion_id_seq OWNED BY public.religion.id;


--
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_permissions (
    role_id integer NOT NULL,
    permission_id integer NOT NULL
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    name character varying(30) NOT NULL
);


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: ruc_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ruc_states (
    id integer NOT NULL,
    name character varying(50) NOT NULL
);


--
-- Name: ruc_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ruc_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ruc_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ruc_states_id_seq OWNED BY public.ruc_states.id;


--
-- Name: school_fee; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.school_fee (
    id integer NOT NULL,
    school_year_id integer NOT NULL,
    level_id integer NOT NULL,
    shift_id integer NOT NULL,
    school_fee_concept_id integer NOT NULL,
    enrollment_price numeric(5,2) NOT NULL,
    tuition_cost numeric(5,2) NOT NULL,
    registration_fee numeric(5,2) NOT NULL,
    description text
);


--
-- Name: school_fee_concepts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.school_fee_concepts (
    id integer NOT NULL,
    name character varying(40) NOT NULL
);


--
-- Name: school_fee_concepts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.school_fee_concepts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: school_fee_concepts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.school_fee_concepts_id_seq OWNED BY public.school_fee_concepts.id;


--
-- Name: school_fee_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.school_fee_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: school_fee_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.school_fee_id_seq OWNED BY public.school_fee.id;


--
-- Name: school_year; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.school_year (
    id integer NOT NULL,
    year smallint NOT NULL,
    start_date date NOT NULL,
    end_date date,
    is_active boolean
);


--
-- Name: school_year_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.school_year_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: school_year_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.school_year_id_seq OWNED BY public.school_year.id;


--
-- Name: school_year_months; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.school_year_months (
    id integer NOT NULL,
    school_year_id integer NOT NULL,
    month smallint NOT NULL,
    billing_open_date date NOT NULL,
    due_date date NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT chk_billing_before_due CHECK ((billing_open_date <= due_date)),
    CONSTRAINT school_year_months_month_check CHECK (((month >= 1) AND (month <= 12)))
);


--
-- Name: school_year_months_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.school_year_months ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.school_year_months_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: second_languages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.second_languages (
    person_id integer NOT NULL,
    second_language_id integer NOT NULL
);


--
-- Name: shifts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shifts (
    id integer NOT NULL,
    name character varying(6) NOT NULL
);


--
-- Name: shifts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shifts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shifts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shifts_id_seq OWNED BY public.shifts.id;


--
-- Name: staff_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_members (
    person_id integer NOT NULL,
    level_of_education_id integer,
    professional_title character varying(200),
    employee_code character varying(15),
    previous_institution text,
    spouse_name character varying(100),
    spouse_document_number character varying(20),
    spouse_occupation character varying(100),
    number_of_children smallint,
    comment text,
    is_active boolean DEFAULT true NOT NULL,
    is_archived boolean DEFAULT false NOT NULL
);


--
-- Name: student_debts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.enrollment_debts ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.student_debts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: student_homes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_homes (
    student_id integer NOT NULL,
    has_electronic_devices boolean NOT NULL,
    has_internet_access boolean NOT NULL
);


--
-- Name: student_school_year_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_school_year_states (
    id integer CONSTRAINT student_states_id_not_null NOT NULL,
    name character varying(40) CONSTRAINT student_states_name_not_null NOT NULL,
    description text CONSTRAINT student_states_description_not_null NOT NULL
);


--
-- Name: student_school_years; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_school_years (
    student_id integer CONSTRAINT student_states_by_year_student_id_not_null NOT NULL,
    status_id integer CONSTRAINT student_states_by_year_status_id_not_null NOT NULL,
    school_year_id integer CONSTRAINT student_states_by_year_school_year_id_not_null NOT NULL
);


--
-- Name: student_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.student_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: student_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.student_states_id_seq OWNED BY public.student_school_year_states.id;


--
-- Name: students; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.students (
    person_id integer NOT NULL,
    birth_ubigeo_id integer NOT NULL,
    has_disability boolean NOT NULL,
    siblings smallint,
    childbirth_type_id integer,
    is_active boolean DEFAULT true NOT NULL,
    birth_order smallint DEFAULT 1 NOT NULL,
    is_archived boolean DEFAULT false NOT NULL
);


--
-- Name: ubigeo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ubigeo (
    district_id integer NOT NULL,
    code character(6) NOT NULL
);


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles (
    user_id integer NOT NULL,
    role_id integer NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    names character varying(50) NOT NULL,
    paternal_lastname character varying(40) NOT NULL,
    maternal_lastname character varying(40) NOT NULL,
    email character varying(50) NOT NULL,
    hashed_password character varying(255) NOT NULL,
    phone character varying(20) NOT NULL,
    is_active boolean NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: v_student_balances; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_student_balances AS
 SELECT sd.id AS debt_id,
    sd.student_id,
    sd.enrollment_id,
    sd.school_year_id,
    ct.code AS charge_type_code,
    ct.name AS charge_type_name,
    sd.amount AS amount_charged,
    COALESCE(sum(
        CASE
            WHEN (p.is_voided = false) THEN pda.amount_applied
            ELSE (0)::numeric
        END), (0)::numeric) AS total_paid,
    (sd.amount - COALESCE(sum(
        CASE
            WHEN (p.is_voided = false) THEN pda.amount_applied
            ELSE (0)::numeric
        END), (0)::numeric)) AS balance_due,
    sd.due_date,
    sd.period_month,
    sy.year AS school_year,
    ds.code AS status_code,
    ds.name AS status_name,
    sd.description,
    sd.notes,
    sd.created_at,
    sd.updated_at
   FROM (((((public.enrollment_debts sd
     JOIN public.charge_types ct ON ((ct.id = sd.charge_type_id)))
     JOIN public.debt_statuses ds ON ((ds.id = sd.status_id)))
     JOIN public.school_year sy ON ((sy.id = sd.school_year_id)))
     LEFT JOIN public.payment_debt_allocations pda ON ((pda.debt_id = sd.id)))
     LEFT JOIN public.payments p ON ((p.id = pda.payment_id)))
  GROUP BY sd.id, sd.student_id, sd.enrollment_id, sd.school_year_id, sy.year, ct.code, ct.name, sd.amount, sd.due_date, sd.period_month, ds.code, ds.name, sd.description, sd.notes, sd.created_at, sd.updated_at;


--
-- Name: v_overdue_debts; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_overdue_debts AS
 SELECT debt_id,
    student_id,
    enrollment_id,
    school_year_id,
    charge_type_code,
    charge_type_name,
    amount_charged,
    total_paid,
    balance_due,
    due_date,
    period_month,
    school_year,
    status_code,
    status_name,
    description,
    notes,
    created_at,
    updated_at,
    (CURRENT_DATE - due_date) AS days_overdue
   FROM public.v_student_balances vb
  WHERE ((due_date < CURRENT_DATE) AND ((status_code)::text <> ALL (ARRAY[('PAID'::character varying)::text, ('CANCELLED'::character varying)::text])))
  ORDER BY (CURRENT_DATE - due_date) DESC;


--
-- Name: work_areas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_areas (
    id integer NOT NULL,
    name character varying(200) NOT NULL
);


--
-- Name: work_areas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.work_areas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: work_areas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.work_areas_id_seq OWNED BY public.work_areas.id;


--
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- Name: audit_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log ALTER COLUMN id SET DEFAULT nextval('public.audit_log_id_seq'::regclass);


--
-- Name: childbirth_type id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.childbirth_type ALTER COLUMN id SET DEFAULT nextval('public.childbirth_type_id_seq'::regclass);


--
-- Name: civil_state id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.civil_state ALTER COLUMN id SET DEFAULT nextval('public.civil_state_id_seq'::regclass);


--
-- Name: department id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.department ALTER COLUMN id SET DEFAULT nextval('public.department_id_seq'::regclass);


--
-- Name: disability_degrees id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disability_degrees ALTER COLUMN id SET DEFAULT nextval('public.disability_degrees_id_seq'::regclass);


--
-- Name: disability_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disability_types ALTER COLUMN id SET DEFAULT nextval('public.disability_types_id_seq'::regclass);


--
-- Name: district id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.district ALTER COLUMN id SET DEFAULT nextval('public.district_id_seq'::regclass);


--
-- Name: document_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_types ALTER COLUMN id SET DEFAULT nextval('public.document_types_id_seq'::regclass);


--
-- Name: employment_contract id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_contract ALTER COLUMN id SET DEFAULT nextval('public.employment_contract_id_seq'::regclass);


--
-- Name: enrollment id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment ALTER COLUMN id SET DEFAULT nextval('public.enrollment_id_seq'::regclass);


--
-- Name: enrollment_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment_states ALTER COLUMN id SET DEFAULT nextval('public.enrollment_states_id_seq'::regclass);


--
-- Name: ethnic_self_identifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ethnic_self_identifications ALTER COLUMN id SET DEFAULT nextval('public.ethnic_self_identifications_id_seq'::regclass);


--
-- Name: familiar_relationship_type id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiar_relationship_type ALTER COLUMN id SET DEFAULT nextval('public.familiar_relationship_type_id_seq'::regclass);


--
-- Name: familiar_student_relationship id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiar_student_relationship ALTER COLUMN id SET DEFAULT nextval('public.familiar_student_relationship_id_seq'::regclass);


--
-- Name: genders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.genders ALTER COLUMN id SET DEFAULT nextval('public.genders_id_seq'::regclass);


--
-- Name: grade_offering_shift_sections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_offering_shift_sections ALTER COLUMN id SET DEFAULT nextval('public.grade_offering_shift_sections_id_seq'::regclass);


--
-- Name: grade_offering_shifts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_offering_shifts ALTER COLUMN id SET DEFAULT nextval('public.grade_offering_shifts_id_seq'::regclass);


--
-- Name: grade_offerings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_offerings ALTER COLUMN id SET DEFAULT nextval('public.grade_offerings_id_seq'::regclass);


--
-- Name: grades id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grades ALTER COLUMN id SET DEFAULT nextval('public.academic_grades_id_seq'::regclass);


--
-- Name: institution id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution ALTER COLUMN id SET DEFAULT nextval('public.institution_id_seq'::regclass);


--
-- Name: job_positions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_positions ALTER COLUMN id SET DEFAULT nextval('public.job_positions_id_seq'::regclass);


--
-- Name: languages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.languages ALTER COLUMN id SET DEFAULT nextval('public.languages_id_seq'::regclass);


--
-- Name: level_of_education id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_of_education ALTER COLUMN id SET DEFAULT nextval('public.level_of_education_id_seq'::regclass);


--
-- Name: levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.levels ALTER COLUMN id SET DEFAULT nextval('public.academic_levels_id_seq'::regclass);


--
-- Name: lunch_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lunch_assignments ALTER COLUMN id SET DEFAULT nextval('public.lunch_assignments_id_seq'::regclass);


--
-- Name: lunch_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lunch_categories ALTER COLUMN id SET DEFAULT nextval('public.lunch_categories_id_seq'::regclass);


--
-- Name: lunches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lunches ALTER COLUMN id SET DEFAULT nextval('public.lunches_id_seq'::regclass);


--
-- Name: payment_methods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods ALTER COLUMN id SET DEFAULT nextval('public.payment_methods_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- Name: person id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person ALTER COLUMN id SET DEFAULT nextval('public.person_id_seq'::regclass);


--
-- Name: province id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.province ALTER COLUMN id SET DEFAULT nextval('public.province_id_seq'::regclass);


--
-- Name: religion id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.religion ALTER COLUMN id SET DEFAULT nextval('public.religion_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: ruc_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ruc_states ALTER COLUMN id SET DEFAULT nextval('public.ruc_states_id_seq'::regclass);


--
-- Name: school_fee id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_fee ALTER COLUMN id SET DEFAULT nextval('public.school_fee_id_seq'::regclass);


--
-- Name: school_fee_concepts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_fee_concepts ALTER COLUMN id SET DEFAULT nextval('public.school_fee_concepts_id_seq'::regclass);


--
-- Name: school_year id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_year ALTER COLUMN id SET DEFAULT nextval('public.school_year_id_seq'::regclass);


--
-- Name: shifts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shifts ALTER COLUMN id SET DEFAULT nextval('public.shifts_id_seq'::regclass);


--
-- Name: student_school_year_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_school_year_states ALTER COLUMN id SET DEFAULT nextval('public.student_states_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: work_areas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_areas ALTER COLUMN id SET DEFAULT nextval('public.work_areas_id_seq'::regclass);


--
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.accounts (id, code, name, parent_account_id, print_code) VALUES (5, '10', 'Efectivo y equivalentes de efectivo', NULL, '1111');
INSERT INTO public.accounts (id, code, name, parent_account_id, print_code) VALUES (7, '10.3', 'Banco BCP', 5, '10101');
INSERT INTO public.accounts (id, code, name, parent_account_id, print_code) VALUES (8, '10.4', 'Checkes ilegales', 5, '90909090');
INSERT INTO public.accounts (id, code, name, parent_account_id, print_code) VALUES (9, '50', 'Bienes inmuebles conseguidos ilegalmente', NULL, '1111');


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: charge_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.charge_types (id, code, name, description, is_active) OVERRIDING SYSTEM VALUE VALUES (1, 'ADMISSION', 'Cuota de Ingreso', 'Pago único vitalicio al ingresar por primera vez al colegio. No se repite en años siguientes.', true);
INSERT INTO public.charge_types (id, code, name, description, is_active) OVERRIDING SYSTEM VALUE VALUES (2, 'ENROLLMENT', 'Matrícula', 'Pago anual requerido para continuar estudiando. Se genera una vez por año escolar.', true);
INSERT INTO public.charge_types (id, code, name, description, is_active) OVERRIDING SYSTEM VALUE VALUES (3, 'TUITION', 'Mensualidad', 'Pago mensual recurrente por la prestación del servicio educativo.', true);


--
-- Data for Name: childbirth_type; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.childbirth_type (id, name) VALUES (1, 'Parto normal (vaginal)');
INSERT INTO public.childbirth_type (id, name) VALUES (2, 'Cesárea');
INSERT INTO public.childbirth_type (id, name) VALUES (3, 'Otro');


--
-- Data for Name: civil_state; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.civil_state (id, name) VALUES (1, 'Soltera/o');
INSERT INTO public.civil_state (id, name) VALUES (2, 'Casada/o');
INSERT INTO public.civil_state (id, name) VALUES (3, 'Divorciada/o');
INSERT INTO public.civil_state (id, name) VALUES (4, 'Viuda/o');


--
-- Data for Name: debt_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.debt_statuses (id, code, name, is_terminal) OVERRIDING SYSTEM VALUE VALUES (1, 'PENDING', 'Pendiente', false);
INSERT INTO public.debt_statuses (id, code, name, is_terminal) OVERRIDING SYSTEM VALUE VALUES (2, 'PARTIALLY_PAID', 'Pago Parcial', false);
INSERT INTO public.debt_statuses (id, code, name, is_terminal) OVERRIDING SYSTEM VALUE VALUES (3, 'PAID', 'Pagado', true);
INSERT INTO public.debt_statuses (id, code, name, is_terminal) OVERRIDING SYSTEM VALUE VALUES (4, 'OVERDUE', 'Vencido', false);
INSERT INTO public.debt_statuses (id, code, name, is_terminal) OVERRIDING SYSTEM VALUE VALUES (5, 'CANCELLED', 'Anulado', true);


--
-- Data for Name: department; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.department (id, name, code) VALUES (1, 'AMAZONAS', '01');
INSERT INTO public.department (id, name, code) VALUES (85, 'ANCASH', '02');
INSERT INTO public.department (id, name, code) VALUES (251, 'APURIMAC', '03');
INSERT INTO public.department (id, name, code) VALUES (335, 'AREQUIPA', '04');
INSERT INTO public.department (id, name, code) VALUES (444, 'AYACUCHO', '05');
INSERT INTO public.department (id, name, code) VALUES (563, 'CAJAMARCA', '06');
INSERT INTO public.department (id, name, code) VALUES (690, 'CALLAO', '07');
INSERT INTO public.department (id, name, code) VALUES (697, 'CUSCO', '08');
INSERT INTO public.department (id, name, code) VALUES (809, 'HUANCAVELICA', '09');
INSERT INTO public.department (id, name, code) VALUES (909, 'HUANUCO', '10');
INSERT INTO public.department (id, name, code) VALUES (993, 'ICA', '11');
INSERT INTO public.department (id, name, code) VALUES (1036, 'JUNIN', '12');
INSERT INTO public.department (id, name, code) VALUES (1160, 'LA LIBERTAD', '13');
INSERT INTO public.department (id, name, code) VALUES (1243, 'LAMBAYEQUE', '14');
INSERT INTO public.department (id, name, code) VALUES (1281, 'LIMA', '15');
INSERT INTO public.department (id, name, code) VALUES (1452, 'LORETO', '16');
INSERT INTO public.department (id, name, code) VALUES (1505, 'MADRE DE DIOS', '17');
INSERT INTO public.department (id, name, code) VALUES (1516, 'MOQUEGUA', '18');
INSERT INTO public.department (id, name, code) VALUES (1536, 'PASCO', '19');
INSERT INTO public.department (id, name, code) VALUES (1565, 'PIURA', '20');
INSERT INTO public.department (id, name, code) VALUES (1630, 'PUNO', '21');
INSERT INTO public.department (id, name, code) VALUES (1740, 'SAN MARTIN', '22');
INSERT INTO public.department (id, name, code) VALUES (1817, 'TACNA', '23');
INSERT INTO public.department (id, name, code) VALUES (1845, 'TUMBES', '24');
INSERT INTO public.department (id, name, code) VALUES (1858, 'UCAYALI', '25');


--
-- Data for Name: disabilities; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: disability_degrees; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.disability_degrees (id, degree) VALUES (1, 'Leve');
INSERT INTO public.disability_degrees (id, degree) VALUES (2, 'Moderado');
INSERT INTO public.disability_degrees (id, degree) VALUES (3, 'Severo');
INSERT INTO public.disability_degrees (id, degree) VALUES (4, 'Profundo');


--
-- Data for Name: disability_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.disability_types (id, type) VALUES (1, 'INTELECTUAL');
INSERT INTO public.disability_types (id, type) VALUES (2, 'FÍSICA');
INSERT INTO public.disability_types (id, type) VALUES (3, 'TEA');
INSERT INTO public.disability_types (id, type) VALUES (4, 'VISUAL');
INSERT INTO public.disability_types (id, type) VALUES (5, 'AUDITIVA');
INSERT INTO public.disability_types (id, type) VALUES (6, 'SORDOCEGUERA');
INSERT INTO public.disability_types (id, type) VALUES (7, 'NIÑOS Y NIÑAS DE ALTO RIESGO');
INSERT INTO public.disability_types (id, type) VALUES (8, 'MULTIDISCAPACIDAD');
INSERT INTO public.disability_types (id, type) VALUES (9, 'OTRAS');


--
-- Data for Name: district; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.district (id, name, province_id, code) VALUES (1, 'CHACHAPOYAS', 1, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (2, 'ASUNCION', 1, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (3, 'BALSAS', 1, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (4, 'CHETO', 1, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (5, 'CHILIQUIN', 1, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (6, 'CHUQUIBAMBA', 1, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (7, 'GRANADA', 1, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (8, 'HUANCAS', 1, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (9, 'LA JALCA', 1, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (10, 'LEIMEBAMBA', 1, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (11, 'LEVANTO', 1, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (12, 'MAGDALENA', 1, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (13, 'MARISCAL CASTILLA', 1, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (14, 'MOLINOPAMPA', 1, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (15, 'MONTEVIDEO', 1, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (16, 'OLLEROS', 1, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (17, 'QUINJALCA', 1, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (18, 'SAN FRANCISCO DE DAGUAS', 1, '18');
INSERT INTO public.district (id, name, province_id, code) VALUES (19, 'SAN ISIDRO DE MAINO', 1, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (20, 'SOLOCO', 1, '20');
INSERT INTO public.district (id, name, province_id, code) VALUES (21, 'SONCHE', 1, '21');
INSERT INTO public.district (id, name, province_id, code) VALUES (22, 'BAGUA', 22, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (23, 'ARAMANGO', 22, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (24, 'COPALLIN', 22, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (25, 'EL PARCO', 22, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (26, 'IMAZA', 22, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (27, 'LA PECA', 22, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (28, 'JUMBILLA', 28, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (29, 'CHISQUILLA', 28, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (30, 'CHURUJA', 28, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (31, 'COROSHA', 28, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (32, 'CUISPES', 28, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (33, 'FLORIDA', 28, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (34, 'JAZAN', 28, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (35, 'RECTA', 28, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (36, 'SAN CARLOS', 28, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (37, 'SHIPASBAMBA', 28, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (38, 'VALERA', 28, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (39, 'YAMBRASBAMBA', 28, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (40, 'NIEVA', 40, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (41, 'EL CENEPA', 40, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (42, 'RIO SANTIAGO', 40, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (43, 'LAMUD', 43, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (44, 'CAMPORREDONDO', 43, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (45, 'COCABAMBA', 43, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (46, 'COLCAMAR', 43, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (47, 'CONILA', 43, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (48, 'INGUILPATA', 43, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (49, 'LONGUITA', 43, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (50, 'LONYA CHICO', 43, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (51, 'LUYA', 43, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (52, 'LUYA VIEJO', 43, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (53, 'MARIA', 43, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (54, 'OCALLI', 43, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (55, 'OCUMAL', 43, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (56, 'PISUQUIA', 43, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (57, 'PROVIDENCIA', 43, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (58, 'SAN CRISTOBAL', 43, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (59, 'SAN FRANCISCO DEL YESO', 43, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (60, 'SAN JERONIMO', 43, '18');
INSERT INTO public.district (id, name, province_id, code) VALUES (61, 'SAN JUAN DE LOPECANCHA', 43, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (62, 'SANTA CATALINA', 43, '20');
INSERT INTO public.district (id, name, province_id, code) VALUES (63, 'SANTO TOMAS', 43, '21');
INSERT INTO public.district (id, name, province_id, code) VALUES (64, 'TINGO', 43, '22');
INSERT INTO public.district (id, name, province_id, code) VALUES (65, 'TRITA', 43, '23');
INSERT INTO public.district (id, name, province_id, code) VALUES (66, 'SAN NICOLAS', 66, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (67, 'CHIRIMOTO', 66, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (68, 'COCHAMAL', 66, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (69, 'HUAMBO', 66, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (70, 'LIMABAMBA', 66, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (71, 'LONGAR', 66, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (72, 'MARISCAL BENAVIDES', 66, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (73, 'MILPUC', 66, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (74, 'OMIA', 66, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (75, 'SANTA ROSA', 66, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (76, 'TOTORA', 66, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (77, 'VISTA ALEGRE', 66, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (78, 'BAGUA GRANDE', 78, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (79, 'CAJARURO', 78, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (80, 'CUMBA', 78, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (81, 'EL MILAGRO', 78, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (82, 'JAMALCA', 78, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (83, 'LONYA GRANDE', 78, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (84, 'YAMON', 78, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (85, 'HUARAZ', 85, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (86, 'COCHABAMBA', 85, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (87, 'COLCABAMBA', 85, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (88, 'HUANCHAY', 85, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (89, 'INDEPENDENCIA', 85, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (90, 'JANGAS', 85, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (91, 'LA LIBERTAD', 85, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (92, 'OLLEROS', 85, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (93, 'PAMPAS GRANDE', 85, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (94, 'PARIACOTO', 85, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (95, 'PIRA', 85, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (96, 'TARICA', 85, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (97, 'AIJA', 97, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (98, 'CORIS', 97, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (99, 'HUACLLAN', 97, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (100, 'LA MERCED', 97, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (101, 'SUCCHA', 97, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (102, 'LLAMELLIN', 102, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (103, 'ACZO', 102, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (104, 'CHACCHO', 102, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (105, 'CHINGAS', 102, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (106, 'MIRGAS', 102, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (107, 'SAN JUAN DE RONTOY', 102, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (108, 'CHACAS', 108, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (109, 'ACOCHACA', 108, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (110, 'CHIQUIAN', 110, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (111, 'ABELARDO PARDO LEZAMETA', 110, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (112, 'ANTONIO RAYMONDI', 110, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (113, 'AQUIA', 110, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (114, 'CAJACAY', 110, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (115, 'CANIS', 110, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (116, 'COLQUIOC', 110, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (117, 'HUALLANCA', 110, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (118, 'HUASTA', 110, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (119, 'HUAYLLACAYAN', 110, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (120, 'LA PRIMAVERA', 110, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (121, 'MANGAS', 110, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (122, 'PACLLON', 110, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (123, 'SAN MIGUEL DE CORPANQUI', 110, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (124, 'TICLLOS', 110, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (125, 'CARHUAZ', 125, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (126, 'ACOPAMPA', 125, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (127, 'AMASHCA', 125, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (128, 'ANTA', 125, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (129, 'ATAQUERO', 125, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (130, 'MARCARA', 125, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (131, 'PARIAHUANCA', 125, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (132, 'SAN MIGUEL DE ACO', 125, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (133, 'SHILLA', 125, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (134, 'TINCO', 125, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (135, 'YUNGAR', 125, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (136, 'SAN LUIS', 136, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (137, 'SAN NICOLAS', 136, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (138, 'YAUYA', 136, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (139, 'CASMA', 139, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (140, 'BUENA VISTA ALTA', 139, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (141, 'COMANDANTE NOEL', 139, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (142, 'YAUTAN', 139, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (143, 'CORONGO', 143, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (144, 'ACO', 143, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (145, 'BAMBAS', 143, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (146, 'CUSCA', 143, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (147, 'LA PAMPA', 143, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (148, 'YANAC', 143, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (149, 'YUPAN', 143, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (150, 'HUARI', 150, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (151, 'ANRA', 150, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (152, 'CAJAY', 150, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (153, 'CHAVIN DE HUANTAR', 150, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (154, 'HUACACHI', 150, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (155, 'HUACCHIS', 150, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (156, 'HUACHIS', 150, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (157, 'HUANTAR', 150, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (158, 'MASIN', 150, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (159, 'PAUCAS', 150, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (160, 'PONTO', 150, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (161, 'RAHUAPAMPA', 150, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (162, 'RAPAYAN', 150, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (163, 'SAN MARCOS', 150, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (164, 'SAN PEDRO DE CHANA', 150, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (165, 'UCO', 150, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (166, 'HUARMEY', 166, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (167, 'COCHAPETI', 166, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (168, 'CULEBRAS', 166, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (169, 'HUAYAN', 166, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (170, 'MALVAS', 166, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (171, 'CARAZ', 171, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (172, 'HUALLANCA', 171, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (173, 'HUATA', 171, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (174, 'HUAYLAS', 171, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (175, 'MATO', 171, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (176, 'PAMPAROMAS', 171, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (177, 'PUEBLO LIBRE', 171, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (178, 'SANTA CRUZ', 171, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (179, 'SANTO TORIBIO', 171, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (180, 'YURACMARCA', 171, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (181, 'PISCOBAMBA', 181, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (182, 'CASCA', 181, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (183, 'ELEAZAR GUZMAN BARRON', 181, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (184, 'FIDEL OLIVAS ESCUDERO', 181, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (185, 'LLAMA', 181, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (186, 'LLUMPA', 181, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (187, 'LUCMA', 181, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (188, 'MUSGA', 181, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (189, 'OCROS', 189, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (190, 'ACAS', 189, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (191, 'CAJAMARQUILLA', 189, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (192, 'CARHUAPAMPA', 189, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (193, 'COCHAS', 189, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (194, 'CONGAS', 189, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (195, 'LLIPA', 189, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (196, 'SAN CRISTOBAL DE RAJAN', 189, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (197, 'SAN PEDRO', 189, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (198, 'SANTIAGO DE CHILCAS', 189, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (199, 'CABANA', 199, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (200, 'BOLOGNESI', 199, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (201, 'CONCHUCOS', 199, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (202, 'HUACASCHUQUE', 199, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (203, 'HUANDOVAL', 199, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (204, 'LACABAMBA', 199, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (205, 'LLAPO', 199, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (206, 'PALLASCA', 199, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (207, 'PAMPAS', 199, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (208, 'SANTA ROSA', 199, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (209, 'TAUCA', 199, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (210, 'POMABAMBA', 210, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (211, 'HUAYLLAN', 210, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (212, 'PAROBAMBA', 210, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (213, 'QUINUABAMBA', 210, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (214, 'RECUAY', 214, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (215, 'CATAC', 214, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (216, 'COTAPARACO', 214, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (217, 'HUAYLLAPAMPA', 214, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (218, 'LLACLLIN', 214, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (219, 'MARCA', 214, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (220, 'PAMPAS CHICO', 214, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (221, 'PARARIN', 214, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (222, 'TAPACOCHA', 214, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (223, 'TICAPAMPA', 214, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (224, 'CHIMBOTE', 224, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (225, 'CACERES DEL PERU', 224, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (226, 'COISHCO', 224, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (227, 'MACATE', 224, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (228, 'MORO', 224, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (229, 'NEPEÑA', 224, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (230, 'SAMANCO', 224, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (231, 'SANTA', 224, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (232, 'NUEVO CHIMBOTE', 224, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (233, 'SIHUAS', 233, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (234, 'ACOBAMBA', 233, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (235, 'ALFONSO UGARTE', 233, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (236, 'CASHAPAMPA', 233, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (237, 'CHINGALPO', 233, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (238, 'HUAYLLABAMBA', 233, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (239, 'QUICHES', 233, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (240, 'RAGASH', 233, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (241, 'SAN JUAN', 233, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (242, 'SICSIBAMBA', 233, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (243, 'YUNGAY', 243, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (244, 'CASCAPARA', 243, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (245, 'MANCOS', 243, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (246, 'MATACOTO', 243, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (247, 'QUILLO', 243, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (248, 'RANRAHIRCA', 243, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (249, 'SHUPLUY', 243, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (250, 'YANAMA', 243, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (251, 'ABANCAY', 251, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (252, 'CHACOCHE', 251, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (253, 'CIRCA', 251, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (254, 'CURAHUASI', 251, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (255, 'HUANIPACA', 251, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (256, 'LAMBRAMA', 251, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (257, 'PICHIRHUA', 251, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (258, 'SAN PEDRO DE CACHORA', 251, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (259, 'TAMBURCO', 251, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (260, 'ANDAHUAYLAS', 260, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (261, 'ANDARAPA', 260, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (262, 'CHIARA', 260, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (263, 'HUANCARAMA', 260, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (264, 'HUANCARAY', 260, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (265, 'HUAYANA', 260, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (266, 'KISHUARA', 260, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (267, 'PACOBAMBA', 260, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (268, 'PACUCHA', 260, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (269, 'PAMPACHIRI', 260, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (270, 'POMACOCHA', 260, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (271, 'SAN ANTONIO DE CACHI', 260, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (272, 'SAN JERONIMO', 260, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (273, 'SAN MIGUEL DE CHACCRAMPA', 260, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (274, 'SANTA MARIA DE CHICMO', 260, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (275, 'TALAVERA', 260, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (276, 'TUMAY HUARACA', 260, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (277, 'TURPO', 260, '18');
INSERT INTO public.district (id, name, province_id, code) VALUES (278, 'KAQUIABAMBA', 260, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (279, 'JOSE MARIA ARGUEDAS', 260, '20');
INSERT INTO public.district (id, name, province_id, code) VALUES (280, 'ANTABAMBA', 280, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (281, 'EL ORO', 280, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (282, 'HUAQUIRCA', 280, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (283, 'JUAN ESPINOZA MEDRANO', 280, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (284, 'OROPESA', 280, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (285, 'PACHACONAS', 280, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (286, 'SABAINO', 280, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (287, 'CHALHUANCA', 287, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (288, 'CAPAYA', 287, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (289, 'CARAYBAMBA', 287, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (290, 'CHAPIMARCA', 287, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (291, 'COLCABAMBA', 287, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (292, 'COTARUSE', 287, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (293, 'HUAYLLO', 287, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (294, 'JUSTO APU SAHUARAURA', 287, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (295, 'LUCRE', 287, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (296, 'POCOHUANCA', 287, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (297, 'SAN JUAN DE CHACÑA', 287, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (298, 'SAÑAYCA', 287, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (299, 'SORAYA', 287, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (300, 'TAPAIRIHUA', 287, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (301, 'TINTAY', 287, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (302, 'TORAYA', 287, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (303, 'YANACA', 287, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (304, 'TAMBOBAMBA', 304, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (305, 'COTABAMBAS', 304, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (306, 'COYLLURQUI', 304, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (307, 'HAQUIRA', 304, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (308, 'MARA', 304, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (309, 'CHALLHUAHUACHO', 304, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (310, 'CHINCHEROS', 310, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (311, 'ANCO_HUALLO', 310, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (312, 'COCHARCAS', 310, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (313, 'HUACCANA', 310, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (314, 'OCOBAMBA', 310, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (315, 'ONGOY', 310, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (316, 'URANMARCA', 310, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (317, 'RANRACANCHA', 310, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (318, 'ROCCHACC', 310, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (319, 'EL PORVENIR', 310, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (320, 'LOS CHANKAS', 310, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (321, 'CHUQUIBAMBILLA', 321, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (322, 'CURPAHUASI', 321, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (323, 'GAMARRA', 321, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (324, 'HUAYLLATI', 321, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (325, 'MAMARA', 321, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (326, 'MICAELA BASTIDAS', 321, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (327, 'PATAYPAMPA', 321, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (328, 'PROGRESO', 321, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (329, 'SAN ANTONIO', 321, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (330, 'SANTA ROSA', 321, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (331, 'TURPAY', 321, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (332, 'VILCABAMBA', 321, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (333, 'VIRUNDO', 321, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (334, 'CURASCO', 321, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (335, 'AREQUIPA', 335, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (336, 'ALTO SELVA ALEGRE', 335, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (337, 'CAYMA', 335, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (338, 'CERRO COLORADO', 335, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (339, 'CHARACATO', 335, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (340, 'CHIGUATA', 335, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (341, 'JACOBO HUNTER', 335, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (342, 'LA JOYA', 335, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (343, 'MARIANO MELGAR', 335, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (344, 'MIRAFLORES', 335, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (345, 'MOLLEBAYA', 335, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (346, 'PAUCARPATA', 335, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (347, 'POCSI', 335, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (348, 'POLOBAYA', 335, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (349, 'QUEQUEÑA', 335, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (350, 'SABANDIA', 335, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (351, 'SACHACA', 335, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (352, 'SAN JUAN DE SIGUAS', 335, '18');
INSERT INTO public.district (id, name, province_id, code) VALUES (353, 'SAN JUAN DE TARUCANI', 335, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (354, 'SANTA ISABEL DE SIGUAS', 335, '20');
INSERT INTO public.district (id, name, province_id, code) VALUES (355, 'SANTA RITA DE SIGUAS', 335, '21');
INSERT INTO public.district (id, name, province_id, code) VALUES (356, 'SOCABAYA', 335, '22');
INSERT INTO public.district (id, name, province_id, code) VALUES (357, 'TIABAYA', 335, '23');
INSERT INTO public.district (id, name, province_id, code) VALUES (358, 'UCHUMAYO', 335, '24');
INSERT INTO public.district (id, name, province_id, code) VALUES (359, 'VITOR', 335, '25');
INSERT INTO public.district (id, name, province_id, code) VALUES (360, 'YANAHUARA', 335, '26');
INSERT INTO public.district (id, name, province_id, code) VALUES (361, 'YARABAMBA', 335, '27');
INSERT INTO public.district (id, name, province_id, code) VALUES (362, 'YURA', 335, '28');
INSERT INTO public.district (id, name, province_id, code) VALUES (363, 'JOSE LUIS BUSTAMANTE Y RIVERO', 335, '29');
INSERT INTO public.district (id, name, province_id, code) VALUES (364, 'CAMANA', 364, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (365, 'JOSE MARIA QUIMPER', 364, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (366, 'MARIANO NICOLAS VALCARCEL', 364, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (367, 'MARISCAL CACERES', 364, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (368, 'NICOLAS DE PIEROLA', 364, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (369, 'OCOÑA', 364, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (370, 'QUILCA', 364, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (371, 'SAMUEL PASTOR', 364, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (372, 'CARAVELI', 372, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (373, 'ACARI', 372, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (374, 'ATICO', 372, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (375, 'ATIQUIPA', 372, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (376, 'BELLA UNION', 372, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (377, 'CAHUACHO', 372, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (378, 'CHALA', 372, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (379, 'CHAPARRA', 372, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (380, 'HUANUHUANU', 372, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (381, 'JAQUI', 372, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (382, 'LOMAS', 372, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (383, 'QUICACHA', 372, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (384, 'YAUCA', 372, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (385, 'APLAO', 385, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (386, 'ANDAGUA', 385, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (387, 'AYO', 385, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (388, 'CHACHAS', 385, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (389, 'CHILCAYMARCA', 385, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (390, 'CHOCO', 385, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (391, 'HUANCARQUI', 385, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (392, 'MACHAGUAY', 385, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (393, 'ORCOPAMPA', 385, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (394, 'PAMPACOLCA', 385, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (395, 'TIPAN', 385, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (396, 'UÑON', 385, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (397, 'URACA', 385, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (398, 'VIRACO', 385, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (399, 'CHIVAY', 399, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (400, 'ACHOMA', 399, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (401, 'CABANACONDE', 399, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (402, 'CALLALLI', 399, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (403, 'CAYLLOMA', 399, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (404, 'COPORAQUE', 399, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (405, 'HUAMBO', 399, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (406, 'HUANCA', 399, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (407, 'ICHUPAMPA', 399, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (408, 'LARI', 399, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (409, 'LLUTA', 399, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (410, 'MACA', 399, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (411, 'MADRIGAL', 399, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (412, 'SAN ANTONIO DE CHUCA', 399, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (413, 'SIBAYO', 399, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (414, 'TAPAY', 399, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (415, 'TISCO', 399, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (416, 'TUTI', 399, '18');
INSERT INTO public.district (id, name, province_id, code) VALUES (417, 'YANQUE', 399, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (418, 'MAJES', 399, '20');
INSERT INTO public.district (id, name, province_id, code) VALUES (419, 'CHUQUIBAMBA', 419, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (420, 'ANDARAY', 419, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (421, 'CAYARANI', 419, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (422, 'CHICHAS', 419, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (423, 'IRAY', 419, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (424, 'RIO GRANDE', 419, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (425, 'SALAMANCA', 419, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (426, 'YANAQUIHUA', 419, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (427, 'MOLLENDO', 427, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (428, 'COCACHACRA', 427, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (429, 'DEAN VALDIVIA', 427, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (430, 'ISLAY', 427, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (431, 'MEJIA', 427, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (432, 'PUNTA DE BOMBON', 427, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (433, 'COTAHUASI', 433, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (434, 'ALCA', 433, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (435, 'CHARCANA', 433, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (436, 'HUAYNACOTAS', 433, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (437, 'PAMPAMARCA', 433, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (438, 'PUYCA', 433, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (439, 'QUECHUALLA', 433, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (440, 'SAYLA', 433, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (441, 'TAURIA', 433, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (442, 'TOMEPAMPA', 433, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (443, 'TORO', 433, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (444, 'AYACUCHO', 444, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (445, 'ACOCRO', 444, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (446, 'ACOS VINCHOS', 444, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (447, 'CARMEN ALTO', 444, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (448, 'CHIARA', 444, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (449, 'OCROS', 444, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (450, 'PACAYCASA', 444, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (451, 'QUINUA', 444, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (452, 'SAN JOSE DE TICLLAS', 444, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (453, 'SAN JUAN BAUTISTA', 444, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (454, 'SANTIAGO DE PISCHA', 444, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (455, 'SOCOS', 444, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (456, 'TAMBILLO', 444, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (457, 'VINCHOS', 444, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (458, 'JESUS NAZARENO', 444, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (459, 'ANDRES AVELINO CACERES DORREGARAY', 444, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (460, 'CANGALLO', 460, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (461, 'CHUSCHI', 460, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (462, 'LOS MOROCHUCOS', 460, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (463, 'MARIA PARADO DE BELLIDO', 460, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (464, 'PARAS', 460, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (465, 'TOTOS', 460, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (466, 'SANCOS', 466, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (467, 'CARAPO', 466, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (468, 'SACSAMARCA', 466, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (469, 'SANTIAGO DE LUCANAMARCA', 466, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (470, 'HUANTA', 470, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (471, 'AYAHUANCO', 470, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (472, 'HUAMANGUILLA', 470, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (473, 'IGUAIN', 470, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (474, 'LURICOCHA', 470, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (475, 'SANTILLANA', 470, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (476, 'SIVIA', 470, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (477, 'LLOCHEGUA', 470, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (478, 'CANAYRE', 470, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (479, 'UCHURACCAY', 470, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (480, 'PUCACOLPA', 470, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (481, 'CHACA', 470, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (482, 'SAN MIGUEL', 482, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (483, 'ANCO', 482, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (484, 'AYNA', 482, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (485, 'CHILCAS', 482, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (486, 'CHUNGUI', 482, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (487, 'LUIS CARRANZA', 482, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (488, 'SANTA ROSA', 482, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (489, 'TAMBO', 482, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (490, 'SAMUGARI', 482, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (491, 'ANCHIHUAY', 482, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (492, 'ORONCCOY', 482, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (493, 'PUQUIO', 493, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (494, 'AUCARA', 493, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (495, 'CABANA', 493, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (496, 'CARMEN SALCEDO', 493, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (497, 'CHAVIÑA', 493, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (498, 'CHIPAO', 493, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (499, 'HUAC-HUAS', 493, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (500, 'LARAMATE', 493, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (501, 'LEONCIO PRADO', 493, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (502, 'LLAUTA', 493, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (503, 'LUCANAS', 493, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (504, 'OCAÑA', 493, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (505, 'OTOCA', 493, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (506, 'SAISA', 493, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (507, 'SAN CRISTOBAL', 493, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (508, 'SAN JUAN', 493, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (509, 'SAN PEDRO', 493, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (510, 'SAN PEDRO DE PALCO', 493, '18');
INSERT INTO public.district (id, name, province_id, code) VALUES (511, 'SANCOS', 493, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (512, 'SANTA ANA DE HUAYCAHUACHO', 493, '20');
INSERT INTO public.district (id, name, province_id, code) VALUES (513, 'SANTA LUCIA', 493, '21');
INSERT INTO public.district (id, name, province_id, code) VALUES (514, 'CORACORA', 514, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (515, 'CHUMPI', 514, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (516, 'CORONEL CASTAÑEDA', 514, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (517, 'PACAPAUSA', 514, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (518, 'PULLO', 514, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (519, 'PUYUSCA', 514, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (520, 'SAN FRANCISCO DE RAVACAYCO', 514, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (521, 'UPAHUACHO', 514, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (522, 'PAUSA', 522, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (523, 'COLTA', 522, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (524, 'CORCULLA', 522, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (525, 'LAMPA', 522, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (526, 'MARCABAMBA', 522, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (527, 'OYOLO', 522, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (528, 'PARARCA', 522, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (529, 'SAN JAVIER DE ALPABAMBA', 522, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (530, 'SAN JOSE DE USHUA', 522, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (531, 'SARA SARA', 522, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (532, 'QUEROBAMBA', 532, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (533, 'BELEN', 532, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (534, 'CHALCOS', 532, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (535, 'CHILCAYOC', 532, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (536, 'HUACAÑA', 532, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (537, 'MORCOLLA', 532, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (538, 'PAICO', 532, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (539, 'SAN PEDRO DE LARCAY', 532, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (540, 'SAN SALVADOR DE QUIJE', 532, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (541, 'SANTIAGO DE PAUCARAY', 532, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (542, 'SORAS', 532, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (543, 'HUANCAPI', 543, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (544, 'ALCAMENCA', 543, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (545, 'APONGO', 543, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (546, 'ASQUIPATA', 543, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (547, 'CANARIA', 543, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (548, 'CAYARA', 543, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (549, 'COLCA', 543, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (550, 'HUAMANQUIQUIA', 543, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (551, 'HUANCARAYLLA', 543, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (552, 'HUAYA', 543, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (553, 'SARHUA', 543, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (554, 'VILCANCHOS', 543, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (555, 'VILCAS HUAMAN', 555, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (556, 'ACCOMARCA', 555, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (557, 'CARHUANCA', 555, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (558, 'CONCEPCION', 555, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (559, 'HUAMBALPA', 555, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (560, 'INDEPENDENCIA', 555, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (561, 'SAURAMA', 555, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (562, 'VISCHONGO', 555, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (563, 'CAJAMARCA', 563, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (564, 'ASUNCION', 563, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (565, 'CHETILLA', 563, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (566, 'COSPAN', 563, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (567, 'ENCAÑADA', 563, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (568, 'JESUS', 563, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (569, 'LLACANORA', 563, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (570, 'LOS BAÑOS DEL INCA', 563, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (571, 'MAGDALENA', 563, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (572, 'MATARA', 563, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (573, 'NAMORA', 563, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (574, 'SAN JUAN', 563, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (575, 'CAJABAMBA', 575, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (576, 'CACHACHI', 575, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (577, 'CONDEBAMBA', 575, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (578, 'SITACOCHA', 575, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (579, 'CELENDIN', 579, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (580, 'CHUMUCH', 579, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (581, 'CORTEGANA', 579, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (582, 'HUASMIN', 579, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (583, 'JORGE CHAVEZ', 579, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (584, 'JOSE GALVEZ', 579, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (585, 'MIGUEL IGLESIAS', 579, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (586, 'OXAMARCA', 579, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (587, 'SOROCHUCO', 579, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (588, 'SUCRE', 579, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (589, 'UTCO', 579, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (590, 'LA LIBERTAD DE PALLAN', 579, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (591, 'CHOTA', 591, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (592, 'ANGUIA', 591, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (593, 'CHADIN', 591, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (594, 'CHIGUIRIP', 591, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (595, 'CHIMBAN', 591, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (596, 'CHOROPAMPA', 591, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (597, 'COCHABAMBA', 591, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (598, 'CONCHAN', 591, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (599, 'HUAMBOS', 591, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (600, 'LAJAS', 591, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (601, 'LLAMA', 591, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (602, 'MIRACOSTA', 591, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (603, 'PACCHA', 591, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (604, 'PION', 591, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (605, 'QUEROCOTO', 591, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (606, 'SAN JUAN DE LICUPIS', 591, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (607, 'TACABAMBA', 591, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (608, 'TOCMOCHE', 591, '18');
INSERT INTO public.district (id, name, province_id, code) VALUES (609, 'CHALAMARCA', 591, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (610, 'CONTUMAZA', 610, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (611, 'CHILETE', 610, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (612, 'CUPISNIQUE', 610, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (613, 'GUZMANGO', 610, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (614, 'SAN BENITO', 610, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (615, 'SANTA CRUZ DE TOLED', 610, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (616, 'TANTARICA', 610, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (617, 'YONAN', 610, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (618, 'CUTERVO', 618, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (619, 'CALLAYUC', 618, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (620, 'CHOROS', 618, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (621, 'CUJILLO', 618, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (622, 'LA RAMADA', 618, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (623, 'PIMPINGOS', 618, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (624, 'QUEROCOTILLO', 618, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (625, 'SAN ANDRES DE CUTERVO', 618, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (626, 'SAN JUAN DE CUTERVO', 618, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (627, 'SAN LUIS DE LUCMA', 618, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (628, 'SANTA CRUZ', 618, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (629, 'SANTO DOMINGO DE LA CAPILLA', 618, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (630, 'SANTO TOMAS', 618, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (631, 'SOCOTA', 618, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (632, 'TORIBIO CASANOVA', 618, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (633, 'BAMBAMARCA', 633, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (634, 'CHUGUR', 633, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (635, 'HUALGAYOC', 633, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (636, 'JAEN', 636, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (637, 'BELLAVISTA', 636, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (638, 'CHONTALI', 636, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (639, 'COLASAY', 636, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (640, 'HUABAL', 636, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (641, 'LAS PIRIAS', 636, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (642, 'POMAHUACA', 636, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (643, 'PUCARA', 636, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (644, 'SALLIQUE', 636, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (645, 'SAN FELIPE', 636, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (646, 'SAN JOSE DEL ALTO', 636, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (647, 'SANTA ROSA', 636, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (648, 'SAN IGNACIO', 648, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (649, 'CHIRINOS', 648, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (650, 'HUARANGO', 648, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (651, 'LA COIPA', 648, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (652, 'NAMBALLE', 648, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (653, 'SAN JOSE DE LOURDES', 648, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (654, 'TABACONAS', 648, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (655, 'PEDRO GALVEZ', 655, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (656, 'CHANCAY', 655, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (657, 'EDUARDO VILLANUEVA', 655, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (658, 'GREGORIO PITA', 655, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (659, 'ICHOCAN', 655, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (660, 'JOSE MANUEL QUIROZ', 655, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (661, 'JOSE SABOGAL', 655, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (662, 'SAN MIGUEL', 662, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (663, 'BOLIVAR', 662, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (664, 'CALQUIS', 662, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (665, 'CATILLUC', 662, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (666, 'EL PRADO', 662, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (667, 'LA FLORIDA', 662, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (668, 'LLAPA', 662, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (669, 'NANCHOC', 662, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (670, 'NIEPOS', 662, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (671, 'SAN GREGORIO', 662, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (672, 'SAN SILVESTRE DE COCHAN', 662, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (673, 'TONGOD', 662, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (674, 'UNION AGUA BLANCA', 662, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (675, 'SAN PABLO', 675, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (676, 'SAN BERNARDINO', 675, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (677, 'SAN LUIS', 675, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (678, 'TUMBADEN', 675, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (679, 'SANTA CRUZ', 679, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (680, 'ANDABAMBA', 679, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (681, 'CATACHE', 679, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (682, 'CHANCAYBAÑOS', 679, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (683, 'LA ESPERANZA', 679, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (684, 'NINABAMBA', 679, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (685, 'PULAN', 679, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (686, 'SAUCEPAMPA', 679, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (687, 'SEXI', 679, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (688, 'UTICYACU', 679, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (689, 'YAUYUCAN', 679, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (690, 'CALLAO', 690, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (691, 'BELLAVISTA', 690, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (692, 'CARMEN DE LA LEGUA REYNOSO', 690, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (693, 'LA PERLA', 690, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (694, 'LA PUNTA', 690, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (695, 'VENTANILLA', 690, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (696, 'MI PERU', 690, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (697, 'CUSCO', 697, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (698, 'CCORCA', 697, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (699, 'POROY', 697, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (700, 'SAN JERONIMO', 697, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (701, 'SAN SEBASTIAN', 697, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (702, 'SANTIAGO', 697, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (703, 'SAYLLA', 697, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (704, 'WANCHAQ', 697, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (705, 'ACOMAYO', 705, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (706, 'ACOPIA', 705, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (707, 'ACOS', 705, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (708, 'MOSOC LLACTA', 705, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (709, 'POMACANCHI', 705, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (710, 'RONDOCAN', 705, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (711, 'SANGARARA', 705, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (712, 'ANTA', 712, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (713, 'ANCAHUASI', 712, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (714, 'CACHIMAYO', 712, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (715, 'CHINCHAYPUJIO', 712, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (716, 'HUAROCONDO', 712, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (717, 'LIMATAMBO', 712, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (718, 'MOLLEPATA', 712, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (719, 'PUCYURA', 712, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (720, 'ZURITE', 712, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (721, 'CALCA', 721, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (722, 'COYA', 721, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (723, 'LAMAY', 721, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (724, 'LARES', 721, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (725, 'PISAC', 721, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (726, 'SAN SALVADOR', 721, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (727, 'TARAY', 721, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (728, 'YANATILE', 721, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (729, 'YANAOCA', 729, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (730, 'CHECCA', 729, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (731, 'KUNTURKANKI', 729, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (732, 'LANGUI', 729, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (733, 'LAYO', 729, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (734, 'PAMPAMARCA', 729, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (735, 'QUEHUE', 729, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (736, 'TUPAC AMARU', 729, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (737, 'SICUANI', 737, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (738, 'CHECACUPE', 737, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (739, 'COMBAPATA', 737, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (740, 'MARANGANI', 737, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (741, 'PITUMARCA', 737, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (742, 'SAN PABLO', 737, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (743, 'SAN PEDRO', 737, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (744, 'TINTA', 737, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (745, 'SANTO TOMAS', 745, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (746, 'CAPACMARCA', 745, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (747, 'CHAMACA', 745, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (748, 'COLQUEMARCA', 745, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (749, 'LIVITACA', 745, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (750, 'LLUSCO', 745, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (751, 'QUIÑOTA', 745, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (752, 'VELILLE', 745, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (753, 'ESPINAR', 753, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (754, 'CONDOROMA', 753, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (755, 'COPORAQUE', 753, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (756, 'OCORURO', 753, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (757, 'PALLPATA', 753, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (758, 'PICHIGUA', 753, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (759, 'SUYCKUTAMBO', 753, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (760, 'ALTO PICHIGUA', 753, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (761, 'SANTA ANA', 761, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (762, 'ECHARATE', 761, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (763, 'HUAYOPATA', 761, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (764, 'MARANURA', 761, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (765, 'OCOBAMBA', 761, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (766, 'QUELLOUNO', 761, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (767, 'KIMBIRI', 761, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (768, 'SANTA TERESA', 761, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (769, 'VILCABAMBA', 761, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (770, 'PICHARI', 761, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (771, 'INKAWASI', 761, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (772, 'VILLA VIRGEN', 761, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (773, 'VILLA KINTIARINA', 761, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (774, 'MEGANTONI', 761, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (775, 'PARURO', 775, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (776, 'ACCHA', 775, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (777, 'CCAPI', 775, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (778, 'COLCHA', 775, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (779, 'HUANOQUITE', 775, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (780, 'OMACHA', 775, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (781, 'PACCARITAMBO', 775, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (782, 'PILLPINTO', 775, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (783, 'YAURISQUE', 775, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (784, 'PAUCARTAMBO', 784, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (785, 'CAICAY', 784, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (786, 'CHALLABAMBA', 784, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (787, 'COLQUEPATA', 784, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (788, 'HUANCARANI', 784, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (789, 'KOSÑIPATA', 784, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (790, 'URCOS', 790, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (791, 'ANDAHUAYLILLAS', 790, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (792, 'CAMANTI', 790, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (793, 'CCARHUAYO', 790, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (794, 'CCATCA', 790, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (795, 'CUSIPATA', 790, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (796, 'HUARO', 790, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (797, 'LUCRE', 790, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (798, 'MARCAPATA', 790, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (799, 'OCONGATE', 790, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (800, 'OROPESA', 790, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (801, 'QUIQUIJANA', 790, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (802, 'URUBAMBA', 802, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (803, 'CHINCHERO', 802, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (804, 'HUAYLLABAMBA', 802, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (805, 'MACHUPICCHU', 802, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (806, 'MARAS', 802, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (807, 'OLLANTAYTAMBO', 802, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (808, 'YUCAY', 802, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (809, 'HUANCAVELICA', 809, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (810, 'ACOBAMBILLA', 809, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (811, 'ACORIA', 809, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (812, 'CONAYCA', 809, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (813, 'CUENCA', 809, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (814, 'HUACHOCOLPA', 809, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (815, 'HUAYLLAHUARA', 809, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (816, 'IZCUCHACA', 809, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (817, 'LARIA', 809, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (818, 'MANTA', 809, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (819, 'MARISCAL CACERES', 809, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (820, 'MOYA', 809, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (821, 'NUEVO OCCORO', 809, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (822, 'PALCA', 809, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (823, 'PILCHACA', 809, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (824, 'VILCA', 809, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (825, 'YAULI', 809, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (826, 'ASCENSION', 809, '18');
INSERT INTO public.district (id, name, province_id, code) VALUES (827, 'HUANDO', 809, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (828, 'ACOBAMBA', 828, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (829, 'ANDABAMBA', 828, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (830, 'ANTA', 828, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (831, 'CAJA', 828, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (832, 'MARCAS', 828, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (833, 'PAUCARA', 828, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (834, 'POMACOCHA', 828, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (835, 'ROSARIO', 828, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (836, 'LIRCAY', 836, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (837, 'ANCHONGA', 836, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (838, 'CALLANMARCA', 836, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (839, 'CCOCHACCASA', 836, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (840, 'CHINCHO', 836, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (841, 'CONGALLA', 836, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (842, 'HUANCA-HUANCA', 836, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (843, 'HUAYLLAY GRANDE', 836, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (844, 'JULCAMARCA', 836, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (845, 'SAN ANTONIO DE ANTAPARCO', 836, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (846, 'SANTO TOMAS DE PATA', 836, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (847, 'SECCLLA', 836, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (848, 'CASTROVIRREYNA', 848, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (849, 'ARMA', 848, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (850, 'AURAHUA', 848, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (851, 'CAPILLAS', 848, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (852, 'CHUPAMARCA', 848, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (853, 'COCAS', 848, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (854, 'HUACHOS', 848, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (855, 'HUAMATAMBO', 848, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (856, 'MOLLEPAMPA', 848, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (857, 'SAN JUAN', 848, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (858, 'SANTA ANA', 848, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (859, 'TANTARA', 848, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (860, 'TICRAPO', 848, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (861, 'CHURCAMPA', 861, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (862, 'ANCO', 861, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (863, 'CHINCHIHUASI', 861, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (864, 'EL CARMEN', 861, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (865, 'LA MERCED', 861, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (866, 'LOCROJA', 861, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (867, 'PAUCARBAMBA', 861, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (868, 'SAN MIGUEL DE MAYOCC', 861, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (869, 'SAN PEDRO DE CORIS', 861, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (870, 'PACHAMARCA', 861, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (871, 'COSME', 861, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (872, 'HUAYTARA', 872, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (873, 'AYAVI', 872, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (874, 'CORDOVA', 872, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (875, 'HUAYACUNDO ARMA', 872, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (876, 'LARAMARCA', 872, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (877, 'OCOYO', 872, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (878, 'PILPICHACA', 872, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (879, 'QUERCO', 872, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (880, 'QUITO-ARMA', 872, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (881, 'SAN ANTONIO DE CUSICANCHA', 872, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (882, 'SAN FRANCISCO DE SANGAYAICO', 872, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (883, 'SAN ISIDRO', 872, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (884, 'SANTIAGO DE CHOCORVOS', 872, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (885, 'SANTIAGO DE QUIRAHUARA', 872, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (886, 'SANTO DOMINGO DE CAPILLAS', 872, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (887, 'TAMBO', 872, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (888, 'PAMPAS', 888, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (889, 'ACOSTAMBO', 888, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (890, 'ACRAQUIA', 888, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (891, 'AHUAYCHA', 888, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (892, 'COLCABAMBA', 888, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (893, 'DANIEL HERNANDEZ', 888, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (894, 'HUACHOCOLPA', 888, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (895, 'HUARIBAMBA', 888, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (896, 'ÑAHUIMPUQUIO', 888, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (897, 'PAZOS', 888, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (898, 'QUISHUAR', 888, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (899, 'SALCABAMBA', 888, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (900, 'SALCAHUASI', 888, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (901, 'SAN MARCOS DE ROCCHAC', 888, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (902, 'SURCUBAMBA', 888, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (903, 'TINTAY PUNCU', 888, '18');
INSERT INTO public.district (id, name, province_id, code) VALUES (904, 'QUICHUAS', 888, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (905, 'ANDAYMARCA', 888, '20');
INSERT INTO public.district (id, name, province_id, code) VALUES (906, 'ROBLE', 888, '21');
INSERT INTO public.district (id, name, province_id, code) VALUES (907, 'PICHOS', 888, '22');
INSERT INTO public.district (id, name, province_id, code) VALUES (908, 'SANTIAGO DE TUCUMA', 888, '23');
INSERT INTO public.district (id, name, province_id, code) VALUES (909, 'HUANUCO', 909, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (910, 'AMARILIS', 909, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (911, 'CHINCHAO', 909, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (912, 'CHURUBAMBA', 909, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (913, 'MARGOS', 909, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (914, 'QUISQUI (KICHKI)', 909, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (915, 'SAN FRANCISCO DE CAYRAN', 909, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (916, 'SAN PEDRO DE CHAULAN', 909, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (917, 'SANTA MARIA DEL VALLE', 909, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (918, 'YARUMAYO', 909, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (919, 'PILLCO MARCA', 909, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (920, 'YACUS', 909, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (921, 'SAN PABLO DE PILLAO', 909, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (922, 'AMBO', 922, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (923, 'CAYNA', 922, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (924, 'COLPAS', 922, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (925, 'CONCHAMARCA', 922, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (926, 'HUACAR', 922, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (927, 'SAN FRANCISCO', 922, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (928, 'SAN RAFAEL', 922, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (929, 'TOMAY KICHWA', 922, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (930, 'LA UNION', 930, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (931, 'CHUQUIS', 930, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (932, 'MARIAS', 930, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (933, 'PACHAS', 930, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (934, 'QUIVILLA', 930, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (935, 'RIPAN', 930, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (936, 'SHUNQUI', 930, '21');
INSERT INTO public.district (id, name, province_id, code) VALUES (937, 'SILLAPATA', 930, '22');
INSERT INTO public.district (id, name, province_id, code) VALUES (938, 'YANAS', 930, '23');
INSERT INTO public.district (id, name, province_id, code) VALUES (939, 'HUACAYBAMBA', 939, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (940, 'CANCHABAMBA', 939, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (941, 'COCHABAMBA', 939, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (942, 'PINRA', 939, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (943, 'LLATA', 943, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (944, 'ARANCAY', 943, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (945, 'CHAVIN DE PARIARCA', 943, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (946, 'JACAS GRANDE', 943, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (947, 'JIRCAN', 943, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (948, 'MIRAFLORES', 943, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (949, 'MONZON', 943, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (950, 'PUNCHAO', 943, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (951, 'PUÑOS', 943, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (952, 'SINGA', 943, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (953, 'TANTAMAYO', 943, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (954, 'RUPA-RUPA', 954, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (955, 'DANIEL ALOMIA ROBLES', 954, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (956, 'HERMILIO VALDIZAN', 954, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (957, 'JOSE CRESPO Y CASTILLO', 954, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (958, 'LUYANDO', 954, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (959, 'MARIANO DAMASO BERAUN', 954, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (960, 'PUCAYACU', 954, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (961, 'CASTILLO GRANDE', 954, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (962, 'PUEBLO NUEVO', 954, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (963, 'SANTO DOMINGO DE ANDA', 954, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (964, 'HUACRACHUCO', 964, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (965, 'CHOLON', 964, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (966, 'SAN BUENAVENTURA', 964, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (967, 'LA MORADA', 964, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (968, 'SANTA ROSA DE ALTO YANAJANCA', 964, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (969, 'PANAO', 969, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (970, 'CHAGLLA', 969, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (971, 'MOLINO', 969, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (972, 'UMARI', 969, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (973, 'PUERTO INCA', 973, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (974, 'CODO DEL POZUZO', 973, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (975, 'HONORIA', 973, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (976, 'TOURNAVISTA', 973, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (977, 'YUYAPICHIS', 973, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (978, 'JESUS', 978, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (979, 'BAÑOS', 978, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (980, 'JIVIA', 978, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (981, 'QUEROPALCA', 978, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (982, 'RONDOS', 978, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (983, 'SAN FRANCISCO DE ASIS', 978, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (984, 'SAN MIGUEL DE CAURI', 978, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (985, 'CHAVINILLO', 985, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (986, 'CAHUAC', 985, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (987, 'CHACABAMBA', 985, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (988, 'APARICIO POMARES', 985, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (989, 'JACAS CHICO', 985, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (990, 'OBAS', 985, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (991, 'PAMPAMARCA', 985, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (992, 'CHORAS', 985, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (993, 'ICA', 993, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (994, 'LA TINGUIÑA', 993, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (995, 'LOS AQUIJES', 993, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (996, 'OCUCAJE', 993, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (997, 'PACHACUTEC', 993, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (998, 'PARCONA', 993, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (999, 'PUEBLO NUEVO', 993, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1000, 'SALAS', 993, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1001, 'SAN JOSE DE LOS MOLINOS', 993, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1002, 'SAN JUAN BAUTISTA', 993, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1003, 'SANTIAGO', 993, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1004, 'SUBTANJALLA', 993, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1005, 'TATE', 993, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1006, 'YAUCA DEL ROSARIO', 993, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (1007, 'CHINCHA ALTA', 1007, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1008, 'ALTO LARAN', 1007, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1009, 'CHAVIN', 1007, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1010, 'CHINCHA BAJA', 1007, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1011, 'EL CARMEN', 1007, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1012, 'GROCIO PRADO', 1007, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1013, 'PUEBLO NUEVO', 1007, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1014, 'SAN JUAN DE YANAC', 1007, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1015, 'SAN PEDRO DE HUACARPANA', 1007, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1016, 'SUNAMPE', 1007, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1017, 'TAMBO DE MORA', 1007, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1018, 'NASCA', 1018, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1019, 'CHANGUILLO', 1018, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1020, 'EL INGENIO', 1018, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1021, 'MARCONA', 1018, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1022, 'VISTA ALEGRE', 1018, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1023, 'PALPA', 1023, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1024, 'LLIPATA', 1023, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1025, 'RIO GRANDE', 1023, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1026, 'SANTA CRUZ', 1023, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1027, 'TIBILLO', 1023, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1028, 'PISCO', 1028, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1029, 'HUANCANO', 1028, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1030, 'HUMAY', 1028, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1031, 'INDEPENDENCIA', 1028, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1032, 'PARACAS', 1028, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1033, 'SAN ANDRES', 1028, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1034, 'SAN CLEMENTE', 1028, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1035, 'TUPAC AMARU INCA', 1028, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1036, 'HUANCAYO', 1036, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1037, 'CARHUACALLANGA', 1036, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1038, 'CHACAPAMPA', 1036, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1039, 'CHICCHE', 1036, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1040, 'CHILCA', 1036, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1041, 'CHONGOS ALTO', 1036, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1042, 'CHUPURO', 1036, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1043, 'COLCA', 1036, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1044, 'CULLHUAS', 1036, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1045, 'EL TAMBO', 1036, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (1046, 'HUACRAPUQUIO', 1036, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (1047, 'HUALHUAS', 1036, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (1048, 'HUANCAN', 1036, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (1049, 'HUASICANCHA', 1036, '20');
INSERT INTO public.district (id, name, province_id, code) VALUES (1050, 'HUAYUCACHI', 1036, '21');
INSERT INTO public.district (id, name, province_id, code) VALUES (1051, 'INGENIO', 1036, '22');
INSERT INTO public.district (id, name, province_id, code) VALUES (1052, 'PARIAHUANCA', 1036, '24');
INSERT INTO public.district (id, name, province_id, code) VALUES (1053, 'PILCOMAYO', 1036, '25');
INSERT INTO public.district (id, name, province_id, code) VALUES (1054, 'PUCARA', 1036, '26');
INSERT INTO public.district (id, name, province_id, code) VALUES (1055, 'QUICHUAY', 1036, '27');
INSERT INTO public.district (id, name, province_id, code) VALUES (1056, 'QUILCAS', 1036, '28');
INSERT INTO public.district (id, name, province_id, code) VALUES (1057, 'SAN AGUSTIN', 1036, '29');
INSERT INTO public.district (id, name, province_id, code) VALUES (1058, 'SAN JERONIMO DE TUNAN', 1036, '30');
INSERT INTO public.district (id, name, province_id, code) VALUES (1059, 'SAÑO', 1036, '32');
INSERT INTO public.district (id, name, province_id, code) VALUES (1060, 'SAPALLANGA', 1036, '33');
INSERT INTO public.district (id, name, province_id, code) VALUES (1061, 'SICAYA', 1036, '34');
INSERT INTO public.district (id, name, province_id, code) VALUES (1062, 'SANTO DOMINGO DE ACOBAMBA', 1036, '35');
INSERT INTO public.district (id, name, province_id, code) VALUES (1063, 'VIQUES', 1036, '36');
INSERT INTO public.district (id, name, province_id, code) VALUES (1064, 'CONCEPCION', 1064, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1065, 'ACO', 1064, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1066, 'ANDAMARCA', 1064, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1067, 'CHAMBARA', 1064, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1068, 'COCHAS', 1064, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1069, 'COMAS', 1064, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1070, 'HEROINAS TOLEDO', 1064, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1071, 'MANZANARES', 1064, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1072, 'MARISCAL CASTILLA', 1064, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1073, 'MATAHUASI', 1064, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1074, 'MITO', 1064, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1075, 'NUEVE DE JULIO', 1064, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1076, 'ORCOTUNA', 1064, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1077, 'SAN JOSE DE QUERO', 1064, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (1078, 'SANTA ROSA DE OCOPA', 1064, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (1079, 'CHANCHAMAYO', 1079, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1080, 'PERENE', 1079, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1081, 'PICHANAQUI', 1079, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1082, 'SAN LUIS DE SHUARO', 1079, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1083, 'SAN RAMON', 1079, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1084, 'VITOC', 1079, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1085, 'JAUJA', 1085, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1086, 'ACOLLA', 1085, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1087, 'APATA', 1085, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1088, 'ATAURA', 1085, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1089, 'CANCHAYLLO', 1085, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1090, 'CURICACA', 1085, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1091, 'EL MANTARO', 1085, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1092, 'HUAMALI', 1085, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1093, 'HUARIPAMPA', 1085, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1094, 'HUERTAS', 1085, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1095, 'JANJAILLO', 1085, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1096, 'JULCAN', 1085, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1097, 'LEONOR ORDOÑEZ', 1085, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1098, 'LLOCLLAPAMPA', 1085, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (1099, 'MARCO', 1085, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (1100, 'MASMA', 1085, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (1101, 'MASMA CHICCHE', 1085, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (1102, 'MOLINOS', 1085, '18');
INSERT INTO public.district (id, name, province_id, code) VALUES (1103, 'MONOBAMBA', 1085, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (1104, 'MUQUI', 1085, '20');
INSERT INTO public.district (id, name, province_id, code) VALUES (1105, 'MUQUIYAUYO', 1085, '21');
INSERT INTO public.district (id, name, province_id, code) VALUES (1106, 'PACA', 1085, '22');
INSERT INTO public.district (id, name, province_id, code) VALUES (1107, 'PACCHA', 1085, '23');
INSERT INTO public.district (id, name, province_id, code) VALUES (1108, 'PANCAN', 1085, '24');
INSERT INTO public.district (id, name, province_id, code) VALUES (1109, 'PARCO', 1085, '25');
INSERT INTO public.district (id, name, province_id, code) VALUES (1110, 'POMACANCHA', 1085, '26');
INSERT INTO public.district (id, name, province_id, code) VALUES (1111, 'RICRAN', 1085, '27');
INSERT INTO public.district (id, name, province_id, code) VALUES (1112, 'SAN LORENZO', 1085, '28');
INSERT INTO public.district (id, name, province_id, code) VALUES (1113, 'SAN PEDRO DE CHUNAN', 1085, '29');
INSERT INTO public.district (id, name, province_id, code) VALUES (1114, 'SAUSA', 1085, '30');
INSERT INTO public.district (id, name, province_id, code) VALUES (1115, 'SINCOS', 1085, '31');
INSERT INTO public.district (id, name, province_id, code) VALUES (1116, 'TUNAN MARCA', 1085, '32');
INSERT INTO public.district (id, name, province_id, code) VALUES (1117, 'YAULI', 1085, '33');
INSERT INTO public.district (id, name, province_id, code) VALUES (1118, 'YAUYOS', 1085, '34');
INSERT INTO public.district (id, name, province_id, code) VALUES (1119, 'JUNIN', 1119, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1120, 'CARHUAMAYO', 1119, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1121, 'ONDORES', 1119, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1122, 'ULCUMAYO', 1119, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1123, 'SATIPO', 1123, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1124, 'COVIRIALI', 1123, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1125, 'LLAYLLA', 1123, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1126, 'MAZAMARI', 1123, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1127, 'PAMPA HERMOSA', 1123, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1128, 'PANGOA', 1123, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1129, 'RIO NEGRO', 1123, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1130, 'RIO TAMBO', 1123, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1131, 'VIZCATAN DEL ENE', 1123, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1132, 'TARMA', 1132, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1133, 'ACOBAMBA', 1132, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1134, 'HUARICOLCA', 1132, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1135, 'HUASAHUASI', 1132, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1136, 'LA UNION', 1132, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1137, 'PALCA', 1132, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1138, 'PALCAMAYO', 1132, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1139, 'SAN PEDRO DE CAJAS', 1132, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1140, 'TAPO', 1132, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1141, 'LA OROYA', 1141, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1142, 'CHACAPALPA', 1141, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1143, 'HUAY-HUAY', 1141, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1144, 'MARCAPOMACOCHA', 1141, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1145, 'MOROCOCHA', 1141, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1146, 'PACCHA', 1141, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1147, 'SANTA BARBARA DE CARHUACAYAN', 1141, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1148, 'SANTA ROSA DE SACCO', 1141, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1149, 'SUITUCANCHA', 1141, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1150, 'YAULI', 1141, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1151, 'CHUPACA', 1151, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1152, 'AHUAC', 1151, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1153, 'CHONGOS BAJO', 1151, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1154, 'HUACHAC', 1151, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1155, 'HUAMANCACA CHICO', 1151, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1156, 'SAN JUAN DE ISCOS', 1151, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1157, 'SAN JUAN DE JARPA', 1151, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1158, 'TRES DE DICIEMBRE', 1151, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1159, 'YANACANCHA', 1151, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1160, 'TRUJILLO', 1160, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1161, 'EL PORVENIR', 1160, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1162, 'FLORENCIA DE MORA', 1160, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1163, 'HUANCHACO', 1160, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1164, 'LA ESPERANZA', 1160, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1165, 'LAREDO', 1160, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1166, 'MOCHE', 1160, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1167, 'POROTO', 1160, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1168, 'SALAVERRY', 1160, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1169, 'SIMBAL', 1160, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1170, 'VICTOR LARCO HERRERA', 1160, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1171, 'ASCOPE', 1171, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1172, 'CHICAMA', 1171, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1173, 'CHOCOPE', 1171, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1174, 'MAGDALENA DE CAO', 1171, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1175, 'PAIJAN', 1171, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1176, 'RAZURI', 1171, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1177, 'SANTIAGO DE CAO', 1171, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1178, 'CASA GRANDE', 1171, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1179, 'BOLIVAR', 1179, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1180, 'BAMBAMARCA', 1179, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1181, 'CONDORMARCA', 1179, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1182, 'LONGOTEA', 1179, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1183, 'UCHUMARCA', 1179, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1184, 'UCUNCHA', 1179, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1185, 'CHEPEN', 1185, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1186, 'PACANGA', 1185, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1187, 'PUEBLO NUEVO', 1185, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1188, 'JULCAN', 1188, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1189, 'CALAMARCA', 1188, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1190, 'CARABAMBA', 1188, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1191, 'HUASO', 1188, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1192, 'OTUZCO', 1192, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1193, 'AGALLPAMPA', 1192, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1194, 'CHARAT', 1192, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1195, 'HUARANCHAL', 1192, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1196, 'LA CUESTA', 1192, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1197, 'MACHE', 1192, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1198, 'PARANDAY', 1192, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1199, 'SALPO', 1192, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1200, 'SINSICAP', 1192, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1201, 'USQUIL', 1192, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (1202, 'SAN PEDRO DE LLOC', 1202, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1203, 'GUADALUPE', 1202, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1204, 'JEQUETEPEQUE', 1202, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1205, 'PACASMAYO', 1202, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1206, 'SAN JOSE', 1202, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1207, 'TAYABAMBA', 1207, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1208, 'BULDIBUYO', 1207, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1209, 'CHILLIA', 1207, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1210, 'HUANCASPATA', 1207, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1211, 'HUAYLILLAS', 1207, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1212, 'HUAYO', 1207, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1213, 'ONGON', 1207, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1214, 'PARCOY', 1207, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1215, 'PATAZ', 1207, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1216, 'PIAS', 1207, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1217, 'SANTIAGO DE CHALLAS', 1207, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1218, 'TAURIJA', 1207, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1219, 'URPAY', 1207, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1220, 'HUAMACHUCO', 1220, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1221, 'CHUGAY', 1220, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1222, 'COCHORCO', 1220, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1223, 'CURGOS', 1220, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1224, 'MARCABAL', 1220, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1225, 'SANAGORAN', 1220, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1226, 'SARIN', 1220, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1227, 'SARTIMBAMBA', 1220, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1228, 'SANTIAGO DE CHUCO', 1228, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1229, 'ANGASMARCA', 1228, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1230, 'CACHICADAN', 1228, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1231, 'MOLLEBAMBA', 1228, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1232, 'MOLLEPATA', 1228, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1233, 'QUIRUVILCA', 1228, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1234, 'SANTA CRUZ DE CHUCA', 1228, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1235, 'SITABAMBA', 1228, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1236, 'CASCAS', 1236, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1237, 'LUCMA', 1236, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1238, 'MARMOT', 1236, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1239, 'SAYAPULLO', 1236, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1240, 'VIRU', 1240, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1241, 'CHAO', 1240, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1242, 'GUADALUPITO', 1240, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1243, 'CHICLAYO', 1243, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1244, 'CHONGOYAPE', 1243, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1245, 'ETEN', 1243, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1246, 'ETEN PUERTO', 1243, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1247, 'JOSE LEONARDO ORTIZ', 1243, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1248, 'LA VICTORIA', 1243, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1249, 'LAGUNAS', 1243, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1250, 'MONSEFU', 1243, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1251, 'NUEVA ARICA', 1243, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1252, 'OYOTUN', 1243, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1253, 'PICSI', 1243, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1254, 'PIMENTEL', 1243, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1255, 'REQUE', 1243, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1256, 'SANTA ROSA', 1243, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (1257, 'SAÑA', 1243, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (1258, 'CAYALTI', 1243, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (1259, 'PATAPO', 1243, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (1260, 'POMALCA', 1243, '18');
INSERT INTO public.district (id, name, province_id, code) VALUES (1261, 'PUCALA', 1243, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (1262, 'TUMAN', 1243, '20');
INSERT INTO public.district (id, name, province_id, code) VALUES (1263, 'FERREÑAFE', 1263, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1264, 'CAÑARIS', 1263, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1265, 'INCAHUASI', 1263, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1266, 'MANUEL ANTONIO MESONES MURO', 1263, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1267, 'PITIPO', 1263, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1268, 'PUEBLO NUEVO', 1263, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1269, 'LAMBAYEQUE', 1269, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1270, 'CHOCHOPE', 1269, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1271, 'ILLIMO', 1269, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1272, 'JAYANCA', 1269, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1273, 'MOCHUMI', 1269, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1274, 'MORROPE', 1269, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1275, 'MOTUPE', 1269, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1276, 'OLMOS', 1269, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1277, 'PACORA', 1269, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1278, 'SALAS', 1269, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1279, 'SAN JOSE', 1269, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1280, 'TUCUME', 1269, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1281, 'LIMA', 1281, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1282, 'ANCON', 1281, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1283, 'ATE', 1281, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1284, 'BARRANCO', 1281, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1285, 'BREÑA', 1281, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1286, 'CARABAYLLO', 1281, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1287, 'CHACLACAYO', 1281, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1288, 'CHORRILLOS', 1281, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1289, 'CIENEGUILLA', 1281, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1290, 'COMAS', 1281, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1291, 'EL AGUSTINO', 1281, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1292, 'INDEPENDENCIA', 1281, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1293, 'JESUS MARIA', 1281, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1294, 'LA MOLINA', 1281, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (1295, 'LA VICTORIA', 1281, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (1296, 'LINCE', 1281, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (1297, 'LOS OLIVOS', 1281, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (1298, 'LURIGANCHO', 1281, '18');
INSERT INTO public.district (id, name, province_id, code) VALUES (1299, 'LURIN', 1281, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (1300, 'MAGDALENA DEL MAR', 1281, '20');
INSERT INTO public.district (id, name, province_id, code) VALUES (1301, 'PUEBLO LIBRE', 1281, '21');
INSERT INTO public.district (id, name, province_id, code) VALUES (1302, 'MIRAFLORES', 1281, '22');
INSERT INTO public.district (id, name, province_id, code) VALUES (1303, 'PACHACAMAC', 1281, '23');
INSERT INTO public.district (id, name, province_id, code) VALUES (1304, 'PUCUSANA', 1281, '24');
INSERT INTO public.district (id, name, province_id, code) VALUES (1305, 'PUENTE PIEDRA', 1281, '25');
INSERT INTO public.district (id, name, province_id, code) VALUES (1306, 'PUNTA HERMOSA', 1281, '26');
INSERT INTO public.district (id, name, province_id, code) VALUES (1307, 'PUNTA NEGRA', 1281, '27');
INSERT INTO public.district (id, name, province_id, code) VALUES (1308, 'RIMAC', 1281, '28');
INSERT INTO public.district (id, name, province_id, code) VALUES (1309, 'SAN BARTOLO', 1281, '29');
INSERT INTO public.district (id, name, province_id, code) VALUES (1310, 'SAN BORJA', 1281, '30');
INSERT INTO public.district (id, name, province_id, code) VALUES (1311, 'SAN ISIDRO', 1281, '31');
INSERT INTO public.district (id, name, province_id, code) VALUES (1312, 'SAN JUAN DE LURIGANCHO', 1281, '32');
INSERT INTO public.district (id, name, province_id, code) VALUES (1313, 'SAN JUAN DE MIRAFLORES', 1281, '33');
INSERT INTO public.district (id, name, province_id, code) VALUES (1314, 'SAN LUIS', 1281, '34');
INSERT INTO public.district (id, name, province_id, code) VALUES (1315, 'SAN MARTIN DE PORRES', 1281, '35');
INSERT INTO public.district (id, name, province_id, code) VALUES (1316, 'SAN MIGUEL', 1281, '36');
INSERT INTO public.district (id, name, province_id, code) VALUES (1317, 'SANTA ANITA', 1281, '37');
INSERT INTO public.district (id, name, province_id, code) VALUES (1318, 'SANTA MARIA DEL MAR', 1281, '38');
INSERT INTO public.district (id, name, province_id, code) VALUES (1319, 'SANTA ROSA', 1281, '39');
INSERT INTO public.district (id, name, province_id, code) VALUES (1320, 'SANTIAGO DE SURCO', 1281, '40');
INSERT INTO public.district (id, name, province_id, code) VALUES (1321, 'SURQUILLO', 1281, '41');
INSERT INTO public.district (id, name, province_id, code) VALUES (1322, 'VILLA EL SALVADOR', 1281, '42');
INSERT INTO public.district (id, name, province_id, code) VALUES (1323, 'VILLA MARIA DEL TRIUNFO', 1281, '43');
INSERT INTO public.district (id, name, province_id, code) VALUES (1324, 'BARRANCA', 1324, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1325, 'PARAMONGA', 1324, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1326, 'PATIVILCA', 1324, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1327, 'SUPE', 1324, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1328, 'SUPE PUERTO', 1324, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1329, 'CAJATAMBO', 1329, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1330, 'COPA', 1329, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1331, 'GORGOR', 1329, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1332, 'HUANCAPON', 1329, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1333, 'MANAS', 1329, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1334, 'CANTA', 1334, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1335, 'ARAHUAY', 1334, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1336, 'HUAMANTANGA', 1334, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1337, 'HUAROS', 1334, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1338, 'LACHAQUI', 1334, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1339, 'SAN BUENAVENTURA', 1334, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1340, 'SANTA ROSA DE QUIVES', 1334, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1341, 'SAN VICENTE DE CAÑETE', 1341, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1342, 'ASIA', 1341, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1343, 'CALANGO', 1341, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1344, 'CERRO AZUL', 1341, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1345, 'CHILCA', 1341, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1346, 'COAYLLO', 1341, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1347, 'IMPERIAL', 1341, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1348, 'LUNAHUANA', 1341, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1349, 'MALA', 1341, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1350, 'NUEVO IMPERIAL', 1341, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1351, 'PACARAN', 1341, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1352, 'QUILMANA', 1341, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1353, 'SAN ANTONIO', 1341, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1354, 'SAN LUIS', 1341, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (1355, 'SANTA CRUZ DE FLORES', 1341, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (1356, 'ZUÑIGA', 1341, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (1357, 'HUARAL', 1357, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1358, 'ATAVILLOS ALTO', 1357, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1359, 'ATAVILLOS BAJO', 1357, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1360, 'AUCALLAMA', 1357, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1361, 'CHANCAY', 1357, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1362, 'IHUARI', 1357, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1363, 'LAMPIAN', 1357, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1364, 'PACARAOS', 1357, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1365, 'SAN MIGUEL DE ACOS', 1357, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1366, 'SANTA CRUZ DE ANDAMARCA', 1357, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1367, 'SUMBILCA', 1357, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1368, 'VEINTISIETE DE NOVIEMBRE', 1357, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1369, 'MATUCANA', 1369, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1370, 'ANTIOQUIA', 1369, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1371, 'CALLAHUANCA', 1369, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1372, 'CARAMPOMA', 1369, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1373, 'CHICLA', 1369, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1374, 'CUENCA', 1369, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1375, 'HUACHUPAMPA', 1369, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1376, 'HUANZA', 1369, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1377, 'HUAROCHIRI', 1369, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1378, 'LAHUAYTAMBO', 1369, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1379, 'LANGA', 1369, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1380, 'LARAOS', 1369, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1381, 'MARIATANA', 1369, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1382, 'RICARDO PALMA', 1369, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (1383, 'SAN ANDRES DE TUPICOCHA', 1369, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (1384, 'SAN ANTONIO', 1369, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (1385, 'SAN BARTOLOME', 1369, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (1386, 'SAN DAMIAN', 1369, '18');
INSERT INTO public.district (id, name, province_id, code) VALUES (1387, 'SAN JUAN DE IRIS', 1369, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (1388, 'SAN JUAN DE TANTARANCHE', 1369, '20');
INSERT INTO public.district (id, name, province_id, code) VALUES (1389, 'SAN LORENZO DE QUINTI', 1369, '21');
INSERT INTO public.district (id, name, province_id, code) VALUES (1390, 'SAN MATEO', 1369, '22');
INSERT INTO public.district (id, name, province_id, code) VALUES (1391, 'SAN MATEO DE OTAO', 1369, '23');
INSERT INTO public.district (id, name, province_id, code) VALUES (1392, 'SAN PEDRO DE CASTA', 1369, '24');
INSERT INTO public.district (id, name, province_id, code) VALUES (1393, 'SAN PEDRO DE HUANCAYRE', 1369, '25');
INSERT INTO public.district (id, name, province_id, code) VALUES (1394, 'SANGALLAYA', 1369, '26');
INSERT INTO public.district (id, name, province_id, code) VALUES (1395, 'SANTA CRUZ DE COCACHACRA', 1369, '27');
INSERT INTO public.district (id, name, province_id, code) VALUES (1396, 'SANTA EULALIA', 1369, '28');
INSERT INTO public.district (id, name, province_id, code) VALUES (1397, 'SANTIAGO DE ANCHUCAYA', 1369, '29');
INSERT INTO public.district (id, name, province_id, code) VALUES (1398, 'SANTIAGO DE TUNA', 1369, '30');
INSERT INTO public.district (id, name, province_id, code) VALUES (1399, 'SANTO DOMINGO DE LOS OLLEROS', 1369, '31');
INSERT INTO public.district (id, name, province_id, code) VALUES (1400, 'SURCO', 1369, '32');
INSERT INTO public.district (id, name, province_id, code) VALUES (1401, 'HUACHO', 1401, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1402, 'AMBAR', 1401, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1403, 'CALETA DE CARQUIN', 1401, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1404, 'CHECRAS', 1401, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1405, 'HUALMAY', 1401, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1406, 'HUAURA', 1401, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1407, 'LEONCIO PRADO', 1401, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1408, 'PACCHO', 1401, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1409, 'SANTA LEONOR', 1401, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1410, 'SANTA MARIA', 1401, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1411, 'SAYAN', 1401, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1412, 'VEGUETA', 1401, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1413, 'OYON', 1413, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1414, 'ANDAJES', 1413, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1415, 'CAUJUL', 1413, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1416, 'COCHAMARCA', 1413, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1417, 'NAVAN', 1413, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1418, 'PACHANGARA', 1413, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1419, 'YAUYOS', 1419, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1420, 'ALIS', 1419, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1421, 'ALLAUCA', 1419, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1422, 'AYAVIRI', 1419, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1423, 'AZANGARO', 1419, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1424, 'CACRA', 1419, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1425, 'CARANIA', 1419, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1426, 'CATAHUASI', 1419, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1427, 'CHOCOS', 1419, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1428, 'COCHAS', 1419, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1429, 'COLONIA', 1419, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1430, 'HONGOS', 1419, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1431, 'HUAMPARA', 1419, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1432, 'HUANCAYA', 1419, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (1433, 'HUANGASCAR', 1419, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (1434, 'HUANTAN', 1419, '16');
INSERT INTO public.district (id, name, province_id, code) VALUES (1435, 'HUAÑEC', 1419, '17');
INSERT INTO public.district (id, name, province_id, code) VALUES (1436, 'LARAOS', 1419, '18');
INSERT INTO public.district (id, name, province_id, code) VALUES (1437, 'LINCHA', 1419, '19');
INSERT INTO public.district (id, name, province_id, code) VALUES (1438, 'MADEAN', 1419, '20');
INSERT INTO public.district (id, name, province_id, code) VALUES (1439, 'MIRAFLORES', 1419, '21');
INSERT INTO public.district (id, name, province_id, code) VALUES (1440, 'OMAS', 1419, '22');
INSERT INTO public.district (id, name, province_id, code) VALUES (1441, 'PUTINZA', 1419, '23');
INSERT INTO public.district (id, name, province_id, code) VALUES (1442, 'QUINCHES', 1419, '24');
INSERT INTO public.district (id, name, province_id, code) VALUES (1443, 'QUINOCAY', 1419, '25');
INSERT INTO public.district (id, name, province_id, code) VALUES (1444, 'SAN JOAQUIN', 1419, '26');
INSERT INTO public.district (id, name, province_id, code) VALUES (1445, 'SAN PEDRO DE PILAS', 1419, '27');
INSERT INTO public.district (id, name, province_id, code) VALUES (1446, 'TANTA', 1419, '28');
INSERT INTO public.district (id, name, province_id, code) VALUES (1447, 'TAURIPAMPA', 1419, '29');
INSERT INTO public.district (id, name, province_id, code) VALUES (1448, 'TOMAS', 1419, '30');
INSERT INTO public.district (id, name, province_id, code) VALUES (1449, 'TUPE', 1419, '31');
INSERT INTO public.district (id, name, province_id, code) VALUES (1450, 'VIÑAC', 1419, '32');
INSERT INTO public.district (id, name, province_id, code) VALUES (1451, 'VITIS', 1419, '33');
INSERT INTO public.district (id, name, province_id, code) VALUES (1452, 'IQUITOS', 1452, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1453, 'ALTO NANAY', 1452, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1454, 'FERNANDO LORES', 1452, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1455, 'INDIANA', 1452, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1456, 'LAS AMAZONAS', 1452, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1457, 'MAZAN', 1452, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1458, 'NAPO', 1452, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1459, 'PUNCHANA', 1452, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1460, 'TORRES CAUSANA', 1452, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1461, 'BELEN', 1452, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1462, 'SAN JUAN BAUTISTA', 1452, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1463, 'YURIMAGUAS', 1463, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1464, 'BALSAPUERTO', 1463, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1465, 'JEBEROS', 1463, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1466, 'LAGUNAS', 1463, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1467, 'SANTA CRUZ', 1463, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1468, 'TENIENTE CESAR LOPEZ ROJAS', 1463, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1469, 'NAUTA', 1469, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1470, 'PARINARI', 1469, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1471, 'TIGRE', 1469, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1472, 'TROMPETEROS', 1469, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1473, 'URARINAS', 1469, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1474, 'RAMON CASTILLA', 1474, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1475, 'PEBAS', 1474, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1476, 'YAVARI', 1474, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1477, 'SAN PABLO', 1474, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1478, 'REQUENA', 1478, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1479, 'ALTO TAPICHE', 1478, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1480, 'CAPELO', 1478, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1481, 'EMILIO SAN MARTIN', 1478, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1482, 'MAQUIA', 1478, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1483, 'PUINAHUA', 1478, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1484, 'SAQUENA', 1478, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1485, 'SOPLIN', 1478, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1486, 'TAPICHE', 1478, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1487, 'JENARO HERRERA', 1478, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1488, 'YAQUERANA', 1478, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1489, 'CONTAMANA', 1489, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1490, 'INAHUAYA', 1489, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1491, 'PADRE MARQUEZ', 1489, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1492, 'PAMPA HERMOSA', 1489, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1493, 'SARAYACU', 1489, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1494, 'VARGAS GUERRA', 1489, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1495, 'BARRANCA', 1495, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1496, 'CAHUAPANAS', 1495, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1497, 'MANSERICHE', 1495, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1498, 'MORONA', 1495, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1499, 'PASTAZA', 1495, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1500, 'ANDOAS', 1495, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1501, 'PUTUMAYO', 1501, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1502, 'ROSA PANDURO', 1501, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1503, 'TENIENTE MANUEL CLAVERO', 1501, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1504, 'YAGUAS', 1501, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1505, 'TAMBOPATA', 1505, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1506, 'INAMBARI', 1505, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1507, 'LAS PIEDRAS', 1505, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1508, 'LABERINTO', 1505, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1509, 'MANU', 1509, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1510, 'FITZCARRALD', 1509, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1511, 'MADRE DE DIOS', 1509, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1512, 'HUEPETUHE', 1509, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1513, 'IÑAPARI', 1513, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1514, 'IBERIA', 1513, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1515, 'TAHUAMANU', 1513, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1516, 'MOQUEGUA', 1516, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1517, 'CARUMAS', 1516, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1518, 'CUCHUMBAYA', 1516, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1519, 'SAMEGUA', 1516, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1520, 'SAN CRISTOBAL', 1516, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1521, 'TORATA', 1516, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1522, 'OMATE', 1522, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1523, 'CHOJATA', 1522, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1524, 'COALAQUE', 1522, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1525, 'ICHUÑA', 1522, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1526, 'LA CAPILLA', 1522, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1527, 'LLOQUE', 1522, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1528, 'MATALAQUE', 1522, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1529, 'PUQUINA', 1522, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1530, 'QUINISTAQUILLAS', 1522, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1531, 'UBINAS', 1522, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1532, 'YUNGA', 1522, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1533, 'ILO', 1533, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1534, 'EL ALGARROBAL', 1533, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1535, 'PACOCHA', 1533, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1536, 'CHAUPIMARCA', 1536, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1537, 'HUACHON', 1536, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1538, 'HUARIACA', 1536, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1539, 'HUAYLLAY', 1536, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1540, 'NINACACA', 1536, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1541, 'PALLANCHACRA', 1536, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1542, 'PAUCARTAMBO', 1536, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1543, 'SAN FRANCISCO DE ASIS DE YARUSYACAN', 1536, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1544, 'SIMON BOLIVAR', 1536, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1545, 'TICLACAYAN', 1536, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1546, 'TINYAHUARCO', 1536, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1547, 'VICCO', 1536, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1548, 'YANACANCHA', 1536, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1549, 'YANAHUANCA', 1549, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1550, 'CHACAYAN', 1549, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1551, 'GOYLLARISQUIZGA', 1549, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1552, 'PAUCAR', 1549, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1553, 'SAN PEDRO DE PILLAO', 1549, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1554, 'SANTA ANA DE TUSI', 1549, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1555, 'TAPUC', 1549, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1556, 'VILCABAMBA', 1549, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1557, 'OXAPAMPA', 1557, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1558, 'CHONTABAMBA', 1557, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1559, 'HUANCABAMBA', 1557, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1560, 'PALCAZU', 1557, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1561, 'POZUZO', 1557, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1562, 'PUERTO BERMUDEZ', 1557, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1563, 'VILLA RICA', 1557, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1564, 'CONSTITUCION', 1557, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1565, 'PIURA', 1565, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1566, 'CASTILLA', 1565, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1567, 'CATACAOS', 1565, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1568, 'CURA MORI', 1565, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1569, 'EL TALLAN', 1565, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1570, 'LA ARENA', 1565, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1571, 'LA UNION', 1565, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1572, 'LAS LOMAS', 1565, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1573, 'TAMBO GRANDE', 1565, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (1574, 'VEINTISEIS DE OCTUBRE', 1565, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (1575, 'AYABACA', 1575, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1576, 'FRIAS', 1575, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1577, 'JILILI', 1575, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1578, 'LAGUNAS', 1575, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1579, 'MONTERO', 1575, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1580, 'PACAIPAMPA', 1575, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1581, 'PAIMAS', 1575, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1582, 'SAPILLICA', 1575, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1583, 'SICCHEZ', 1575, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1584, 'SUYO', 1575, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1585, 'HUANCABAMBA', 1585, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1586, 'CANCHAQUE', 1585, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1587, 'EL CARMEN DE LA FRONTERA', 1585, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1588, 'HUARMACA', 1585, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1589, 'LALAQUIZ', 1585, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1590, 'SAN MIGUEL DE EL FAIQUE', 1585, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1591, 'SONDOR', 1585, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1592, 'SONDORILLO', 1585, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1593, 'CHULUCANAS', 1593, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1594, 'BUENOS AIRES', 1593, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1595, 'CHALACO', 1593, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1596, 'LA MATANZA', 1593, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1597, 'MORROPON', 1593, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1598, 'SALITRAL', 1593, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1599, 'SAN JUAN DE BIGOTE', 1593, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1600, 'SANTA CATALINA DE MOSSA', 1593, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1601, 'SANTO DOMINGO', 1593, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1602, 'YAMANGO', 1593, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1603, 'PAITA', 1603, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1604, 'AMOTAPE', 1603, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1605, 'ARENAL', 1603, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1606, 'COLAN', 1603, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1607, 'LA HUACA', 1603, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1608, 'TAMARINDO', 1603, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1609, 'VICHAYAL', 1603, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1610, 'SULLANA', 1610, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1611, 'BELLAVISTA', 1610, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1612, 'IGNACIO ESCUDERO', 1610, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1613, 'LANCONES', 1610, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1614, 'MARCAVELICA', 1610, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1615, 'MIGUEL CHECA', 1610, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1616, 'QUERECOTILLO', 1610, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1617, 'SALITRAL', 1610, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1618, 'PARIÑAS', 1618, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1619, 'EL ALTO', 1618, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1620, 'LA BREA', 1618, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1621, 'LOBITOS', 1618, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1622, 'LOS ORGANOS', 1618, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1623, 'MANCORA', 1618, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1624, 'SECHURA', 1624, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1625, 'BELLAVISTA DE LA UNION', 1624, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1626, 'BERNAL', 1624, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1627, 'CRISTO NOS VALGA', 1624, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1628, 'VICE', 1624, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1629, 'RINCONADA LLICUAR', 1624, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1630, 'PUNO', 1630, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1631, 'ACORA', 1630, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1632, 'AMANTANI', 1630, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1633, 'ATUNCOLLA', 1630, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1634, 'CAPACHICA', 1630, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1635, 'CHUCUITO', 1630, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1636, 'COATA', 1630, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1637, 'HUATA', 1630, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1638, 'MAÑAZO', 1630, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1639, 'PAUCARCOLLA', 1630, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1640, 'PICHACANI', 1630, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1641, 'PLATERIA', 1630, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1642, 'SAN ANTONIO', 1630, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1643, 'TIQUILLACA', 1630, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (1644, 'VILQUE', 1630, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (1645, 'AZANGARO', 1645, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1646, 'ACHAYA', 1645, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1647, 'ARAPA', 1645, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1648, 'ASILLO', 1645, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1649, 'CAMINACA', 1645, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1650, 'CHUPA', 1645, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1651, 'JOSE DOMINGO CHOQUEHUANCA', 1645, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1652, 'MUÑANI', 1645, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1653, 'POTONI', 1645, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1654, 'SAMAN', 1645, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1655, 'SAN ANTON', 1645, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1656, 'SAN JOSE', 1645, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1657, 'SAN JUAN DE SALINAS', 1645, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1658, 'SANTIAGO DE PUPUJA', 1645, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (1659, 'TIRAPATA', 1645, '15');
INSERT INTO public.district (id, name, province_id, code) VALUES (1660, 'MACUSANI', 1660, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1661, 'AJOYANI', 1660, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1662, 'AYAPATA', 1660, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1663, 'COASA', 1660, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1664, 'CORANI', 1660, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1665, 'CRUCERO', 1660, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1666, 'ITUATA', 1660, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1667, 'OLLACHEA', 1660, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1668, 'SAN GABAN', 1660, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1669, 'USICAYOS', 1660, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1670, 'JULI', 1670, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1671, 'DESAGUADERO', 1670, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1672, 'HUACULLANI', 1670, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1673, 'KELLUYO', 1670, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1674, 'PISACOMA', 1670, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1675, 'POMATA', 1670, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1676, 'ZEPITA', 1670, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1677, 'ILAVE', 1677, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1678, 'CAPAZO', 1677, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1679, 'PILCUYO', 1677, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1680, 'SANTA ROSA', 1677, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1681, 'CONDURIRI', 1677, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1682, 'HUANCANE', 1682, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1683, 'COJATA', 1682, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1684, 'HUATASANI', 1682, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1685, 'INCHUPALLA', 1682, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1686, 'PUSI', 1682, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1687, 'ROSASPATA', 1682, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1688, 'TARACO', 1682, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1689, 'VILQUE CHICO', 1682, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1690, 'LAMPA', 1690, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1691, 'CABANILLA', 1690, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1692, 'CALAPUJA', 1690, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1693, 'NICASIO', 1690, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1694, 'OCUVIRI', 1690, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1695, 'PALCA', 1690, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1696, 'PARATIA', 1690, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1697, 'PUCARA', 1690, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1698, 'SANTA LUCIA', 1690, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1699, 'VILAVILA', 1690, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1700, 'AYAVIRI', 1700, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1701, 'ANTAUTA', 1700, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1702, 'CUPI', 1700, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1703, 'LLALLI', 1700, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1704, 'MACARI', 1700, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1705, 'NUÑOA', 1700, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1706, 'ORURILLO', 1700, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1707, 'SANTA ROSA', 1700, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1708, 'UMACHIRI', 1700, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1709, 'MOHO', 1709, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1710, 'CONIMA', 1709, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1711, 'HUAYRAPATA', 1709, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1712, 'TILALI', 1709, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1713, 'PUTINA', 1713, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1714, 'ANANEA', 1713, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1715, 'PEDRO VILCA APAZA', 1713, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1716, 'QUILCAPUNCU', 1713, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1717, 'SINA', 1713, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1718, 'JULIACA', 1718, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1719, 'CABANA', 1718, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1720, 'CABANILLAS', 1718, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1721, 'CARACOTO', 1718, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1722, 'SAN MIGUEL', 1718, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1723, 'SANDIA', 1723, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1724, 'CUYOCUYO', 1723, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1725, 'LIMBANI', 1723, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1726, 'PATAMBUCO', 1723, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1727, 'PHARA', 1723, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1728, 'QUIACA', 1723, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1729, 'SAN JUAN DEL ORO', 1723, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1730, 'YANAHUAYA', 1723, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1731, 'ALTO INAMBARI', 1723, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1732, 'SAN PEDRO DE PUTINA PUNCO', 1723, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1733, 'YUNGUYO', 1733, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1734, 'ANAPIA', 1733, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1735, 'COPANI', 1733, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1736, 'CUTURAPI', 1733, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1737, 'OLLARAYA', 1733, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1738, 'TINICACHI', 1733, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1739, 'UNICACHI', 1733, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1740, 'MOYOBAMBA', 1740, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1741, 'CALZADA', 1740, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1742, 'HABANA', 1740, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1743, 'JEPELACIO', 1740, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1744, 'SORITOR', 1740, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1745, 'YANTALO', 1740, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1746, 'BELLAVISTA', 1746, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1747, 'ALTO BIAVO', 1746, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1748, 'BAJO BIAVO', 1746, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1749, 'HUALLAGA', 1746, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1750, 'SAN PABLO', 1746, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1751, 'SAN RAFAEL', 1746, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1752, 'SAN JOSE DE SISA', 1752, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1753, 'AGUA BLANCA', 1752, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1754, 'SAN MARTIN', 1752, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1755, 'SANTA ROSA', 1752, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1756, 'SHATOJA', 1752, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1757, 'SAPOSOA', 1757, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1758, 'ALTO SAPOSOA', 1757, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1759, 'EL ESLABON', 1757, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1760, 'PISCOYACU', 1757, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1761, 'SACANCHE', 1757, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1762, 'TINGO DE SAPOSOA', 1757, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1763, 'LAMAS', 1763, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1764, 'ALONSO DE ALVARADO', 1763, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1765, 'BARRANQUITA', 1763, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1766, 'CAYNARACHI', 1763, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1767, 'CUÑUMBUQUI', 1763, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1768, 'PINTO RECODO', 1763, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1769, 'RUMISAPA', 1763, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1770, 'SAN ROQUE DE CUMBAZA', 1763, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1771, 'SHANAO', 1763, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1772, 'TABALOSOS', 1763, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1773, 'ZAPATERO', 1763, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1774, 'JUANJUI', 1774, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1775, 'CAMPANILLA', 1774, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1776, 'HUICUNGO', 1774, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1777, 'PACHIZA', 1774, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1778, 'PAJARILLO', 1774, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1779, 'PICOTA', 1779, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1780, 'BUENOS AIRES', 1779, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1781, 'CASPISAPA', 1779, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1782, 'PILLUANA', 1779, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1783, 'PUCACACA', 1779, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1784, 'SAN CRISTOBAL', 1779, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1785, 'SAN HILARION', 1779, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1786, 'SHAMBOYACU', 1779, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1787, 'TINGO DE PONASA', 1779, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1788, 'TRES UNIDOS', 1779, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1789, 'RIOJA', 1789, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1790, 'AWAJUN', 1789, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1791, 'ELIAS SOPLIN VARGAS', 1789, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1792, 'NUEVA CAJAMARCA', 1789, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1793, 'PARDO MIGUEL', 1789, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1794, 'POSIC', 1789, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1795, 'SAN FERNANDO', 1789, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1796, 'YORONGOS', 1789, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1797, 'YURACYACU', 1789, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1798, 'TARAPOTO', 1798, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1799, 'ALBERTO LEVEAU', 1798, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1800, 'CACATACHI', 1798, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1801, 'CHAZUTA', 1798, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1802, 'CHIPURANA', 1798, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1803, 'EL PORVENIR', 1798, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1804, 'HUIMBAYOC', 1798, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1805, 'JUAN GUERRA', 1798, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1806, 'LA BANDA DE SHILCAYO', 1798, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1807, 'MORALES', 1798, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1808, 'PAPAPLAYA', 1798, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1809, 'SAN ANTONIO', 1798, '12');
INSERT INTO public.district (id, name, province_id, code) VALUES (1810, 'SAUCE', 1798, '13');
INSERT INTO public.district (id, name, province_id, code) VALUES (1811, 'SHAPAJA', 1798, '14');
INSERT INTO public.district (id, name, province_id, code) VALUES (1812, 'TOCACHE', 1812, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1813, 'NUEVO PROGRESO', 1812, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1814, 'POLVORA', 1812, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1815, 'SHUNTE', 1812, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1816, 'UCHIZA', 1812, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1817, 'TACNA', 1817, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1818, 'ALTO DE LA ALIANZA', 1817, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1819, 'CALANA', 1817, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1820, 'CIUDAD NUEVA', 1817, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1821, 'INCLAN', 1817, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1822, 'PACHIA', 1817, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1823, 'PALCA', 1817, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1824, 'POCOLLAY', 1817, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1825, 'SAMA', 1817, '09');
INSERT INTO public.district (id, name, province_id, code) VALUES (1826, 'CORONEL GREGORIO ALBARRACIN LANCHIPA', 1817, '10');
INSERT INTO public.district (id, name, province_id, code) VALUES (1827, 'LA YARADA LOS PALOS', 1817, '11');
INSERT INTO public.district (id, name, province_id, code) VALUES (1828, 'CANDARAVE', 1828, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1829, 'CAIRANI', 1828, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1830, 'CAMILACA', 1828, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1831, 'CURIBAYA', 1828, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1832, 'HUANUARA', 1828, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1833, 'QUILAHUANI', 1828, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1834, 'LOCUMBA', 1834, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1835, 'ILABAYA', 1834, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1836, 'ITE', 1834, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1837, 'TARATA', 1837, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1838, 'HEROES ALBARRACIN', 1837, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1839, 'ESTIQUE', 1837, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1840, 'ESTIQUE-PAMPA', 1837, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1841, 'SITAJARA', 1837, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1842, 'SUSAPAYA', 1837, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1843, 'TARUCACHI', 1837, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1844, 'TICACO', 1837, '08');
INSERT INTO public.district (id, name, province_id, code) VALUES (1845, 'TUMBES', 1845, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1846, 'CORRALES', 1845, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1847, 'LA CRUZ', 1845, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1848, 'PAMPAS DE HOSPITAL', 1845, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1849, 'SAN JACINTO', 1845, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1850, 'SAN JUAN DE LA VIRGEN', 1845, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1851, 'ZORRITOS', 1851, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1852, 'CASITAS', 1851, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1853, 'CANOAS DE PUNTA SAL', 1851, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1854, 'ZARUMILLA', 1854, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1855, 'AGUAS VERDES', 1854, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1856, 'MATAPALO', 1854, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1857, 'PAPAYAL', 1854, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1858, 'CALLERIA', 1858, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1859, 'CAMPOVERDE', 1858, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1860, 'IPARIA', 1858, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1861, 'MASISEA', 1858, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1862, 'YARINACOCHA', 1858, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1863, 'NUEVA REQUENA', 1858, '06');
INSERT INTO public.district (id, name, province_id, code) VALUES (1864, 'MANANTAY', 1858, '07');
INSERT INTO public.district (id, name, province_id, code) VALUES (1865, 'RAIMONDI', 1865, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1866, 'SEPAHUA', 1865, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1867, 'TAHUANIA', 1865, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1868, 'YURUA', 1865, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1869, 'PADRE ABAD', 1869, '01');
INSERT INTO public.district (id, name, province_id, code) VALUES (1870, 'IRAZOLA', 1869, '02');
INSERT INTO public.district (id, name, province_id, code) VALUES (1871, 'CURIMANA', 1869, '03');
INSERT INTO public.district (id, name, province_id, code) VALUES (1872, 'NESHUYA', 1869, '04');
INSERT INTO public.district (id, name, province_id, code) VALUES (1873, 'ALEXANDER VON HUMBOLDT', 1869, '05');
INSERT INTO public.district (id, name, province_id, code) VALUES (1874, 'PURUS', 1874, '01');


--
-- Data for Name: document_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.document_types (id, name) VALUES (1, 'DNI');
INSERT INTO public.document_types (id, name) VALUES (2, 'CÓDIGO DE ESTUDIANTE');
INSERT INTO public.document_types (id, name) VALUES (3, 'CE');
INSERT INTO public.document_types (id, name) VALUES (4, 'PTP');
INSERT INTO public.document_types (id, name) VALUES (5, 'OTRO');


--
-- Data for Name: employment_contract; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.employment_contract (id, staff_member_id, institution_id, school_year_id, job_position_id, area_id, start_date, end_date, salary) VALUES (1, 43, 3, 17, 9, 9, '2026-06-16', '2026-10-31', 1000.00);
INSERT INTO public.employment_contract (id, staff_member_id, institution_id, school_year_id, job_position_id, area_id, start_date, end_date, salary) VALUES (2, 43, 3, 18, 25, 9, '2027-06-01', '2027-12-31', 1000.00);
INSERT INTO public.employment_contract (id, staff_member_id, institution_id, school_year_id, job_position_id, area_id, start_date, end_date, salary) VALUES (3, 48, 3, 17, 18, 5, '2026-06-01', '2030-12-31', 1000.00);


--
-- Data for Name: enrollment; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (2, '2026-000001', 1, 441, 37, 2, NULL, 17, '2026-05-15', 1, false);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (3, '2027-000001', 1, 531, 37, 2, NULL, 18, '2026-05-15', 1, false);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (4, '2028-000001', 1, 536, 37, 1, NULL, 19, '2026-05-15', 1, false);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (9, '2029-000001', 1, 564, 37, 2, NULL, 20, '2026-05-15', 1, false);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (5, '2014-000001', 1, 111, 37, 1, NULL, 5, '2026-05-15', 1, true);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (10, '2029-000002', 2, 565, 39, 5, NULL, 20, '2026-05-15', 1, false);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (8, '2028-000002', 2, 554, 39, 5, NULL, 19, '2026-05-15', 1, false);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (7, '2027-000002', 2, 532, 39, 5, NULL, 18, '2026-05-15', 1, false);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (13, '2026-000002', 2, 33, 39, 1, NULL, 17, '2026-05-16', 1, true);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (11, '2030-000001', 1, 592, 37, 5, NULL, 21, '2026-05-16', 1, false);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (12, '2030-000002', 2, 594, 39, 5, NULL, 21, '2026-05-16', 1, false);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (15, '2031-000001', 1, 603, 37, 3, NULL, 22, '2026-05-19', 1, false);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (16, '2031-000002', 2, 605, 41, 4, NULL, 22, '2026-05-19', 1, true);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (14, '2026-000003', 3, 475, 41, 5, NULL, 17, '2026-05-19', 1, false);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (17, '2026-000004', 4, 373, 44, 3, 'San Martín', 17, '2026-06-06', 1, true);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (18, '2026-000005', 5, 475, 46, 2, NULL, 17, '2026-06-17', 1, true);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (19, '2028-000003', 3, 540, 41, 3, NULL, 19, '2026-06-17', 1, false);
INSERT INTO public.enrollment (id, code, code_number, grade_offering_shift_section_id, student_id, school_fee_concept_id, previous_school, school_year_id, enrollment_date, state_id, isnew) VALUES (20, '2027-000003', 3, 532, 41, 1, NULL, 18, '2026-06-17', 1, false);


--
-- Data for Name: enrollment_debts; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (80, 37, 5, 5, 3, 140.00, 'Pensión Junio - 2014', '2014-06-30', 6, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (71, 46, 18, 17, 1, 165.38, 'Cuota de Ingreso 2026', '2026-03-31', NULL, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:27:00.993239-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (72, 44, 17, 17, 1, 165.38, 'Cuota de Ingreso 2026', '2026-03-31', NULL, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:27:00.993239-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (73, 39, 13, 17, 1, 165.38, 'Cuota de Ingreso 2026', '2026-03-31', NULL, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:27:00.993239-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (75, 37, 5, 5, 2, 300.00, 'Matrícula 2014', '2014-03-31', NULL, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:27:00.993239-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (76, 39, 13, 17, 2, 330.75, 'Matrícula 2026', '2026-03-31', NULL, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:27:00.993239-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (77, 41, 14, 17, 2, 297.68, 'Matrícula 2026', '2026-03-31', NULL, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:27:00.993239-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (78, 44, 17, 17, 2, 330.75, 'Matrícula 2026', '2026-03-31', NULL, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:27:00.993239-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (79, 46, 18, 17, 2, 330.75, 'Matrícula 2026', '2026-03-31', NULL, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:27:00.993239-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (81, 44, 17, 17, 3, 330.75, 'Pensión Mayo - 2026', '2026-05-31', 5, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (82, 39, 13, 17, 3, 330.75, 'Pensión Junio - 2026', '2026-06-30', 6, 1, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (83, 41, 14, 17, 3, 297.68, 'Pensión Abril - 2026', '2026-04-30', 4, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (85, 41, 14, 17, 3, 297.68, 'Pensión Marzo - 2026', '2026-03-31', 3, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (86, 46, 18, 17, 3, 330.75, 'Pensión Mayo - 2026', '2026-05-31', 5, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (87, 37, 5, 5, 3, 140.00, 'Pensión Agosto - 2014', '2014-08-31', 8, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (88, 37, 5, 5, 3, 140.00, 'Pensión Julio - 2014', '2014-07-31', 7, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (89, 37, 5, 5, 3, 140.00, 'Pensión Septiembre - 2014', '2014-09-30', 9, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (90, 39, 13, 17, 3, 330.75, 'Pensión Marzo - 2026', '2026-03-31', 3, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (91, 37, 5, 5, 3, 140.00, 'Pensión Marzo - 2014', '2014-03-31', 3, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (92, 39, 13, 17, 3, 330.75, 'Pensión Abril - 2026', '2026-04-30', 4, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (93, 41, 14, 17, 3, 297.68, 'Pensión Junio - 2026', '2026-06-30', 6, 1, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (94, 37, 5, 5, 3, 140.00, 'Pensión Abril - 2014', '2014-04-30', 4, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (95, 46, 18, 17, 3, 330.75, 'Pensión Marzo - 2026', '2026-03-31', 3, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (96, 37, 5, 5, 3, 140.00, 'Pensión Diciembre - 2014', '2014-12-31', 12, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (97, 37, 5, 5, 3, 140.00, 'Pensión Octubre - 2014', '2014-10-31', 10, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (98, 41, 14, 17, 3, 297.68, 'Pensión Mayo - 2026', '2026-05-31', 5, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (99, 44, 17, 17, 3, 330.75, 'Pensión Abril - 2026', '2026-04-30', 4, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (100, 37, 5, 5, 3, 140.00, 'Pensión Noviembre - 2014', '2014-11-30', 11, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (102, 46, 18, 17, 3, 330.75, 'Pensión Abril - 2026', '2026-04-30', 4, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (104, 44, 17, 17, 3, 330.75, 'Pensión Marzo - 2026', '2026-03-31', 3, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (106, 46, 18, 17, 3, 330.75, 'Pensión Junio - 2026', '2026-06-30', 6, 1, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (107, 37, 5, 5, 3, 140.00, 'Pensión Mayo - 2014', '2014-05-31', 5, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (108, 44, 17, 17, 3, 330.75, 'Pensión Junio - 2026', '2026-06-30', 6, 1, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (109, 39, 13, 17, 3, 330.75, 'Pensión Mayo - 2026', '2026-05-31', 5, 4, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:30:52.940817-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (74, 37, 2, 17, 2, 330.75, 'Matrícula 2026', '2026-03-31', NULL, 3, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:35:15.226346-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (101, 37, 2, 17, 3, 330.75, 'Pensión Marzo - 2026', '2026-03-31', 3, 3, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:35:15.226346-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (84, 37, 2, 17, 3, 330.75, 'Pensión Mayo - 2026', '2026-05-31', 5, 3, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:35:32.321174-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (103, 37, 2, 17, 3, 330.75, 'Pensión Abril - 2026', '2026-04-30', 4, 3, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:35:32.321174-03', NULL);
INSERT INTO public.enrollment_debts (id, student_id, enrollment_id, school_year_id, charge_type_id, amount, description, due_date, period_month, status_id, notes, created_at, updated_at, created_by) OVERRIDING SYSTEM VALUE VALUES (105, 37, 2, 17, 3, 330.75, 'Pensión Junio - 2026', '2026-06-30', 6, 3, NULL, '2026-06-22 15:27:00.993239-03', '2026-06-22 15:35:44.157534-03', NULL);


--
-- Data for Name: enrollment_states; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.enrollment_states (id, name) VALUES (1, 'Activa');
INSERT INTO public.enrollment_states (id, name) VALUES (2, 'Cancelada');
INSERT INTO public.enrollment_states (id, name) VALUES (3, 'Retirada');
INSERT INTO public.enrollment_states (id, name) VALUES (4, 'Finalizada');


--
-- Data for Name: ethnic_self_identifications; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.ethnic_self_identifications (id, ethnic_self_identification) VALUES (1, 'QUECHUA');
INSERT INTO public.ethnic_self_identifications (id, ethnic_self_identification) VALUES (2, 'AIMARA');
INSERT INTO public.ethnic_self_identifications (id, ethnic_self_identification) VALUES (3, 'INDÍGENA U ORIGINARIO DE LA AMAZONÍA');
INSERT INTO public.ethnic_self_identifications (id, ethnic_self_identification) VALUES (4, 'AFRODESCENDIENTE');
INSERT INTO public.ethnic_self_identifications (id, ethnic_self_identification) VALUES (5, 'OTRO');


--
-- Data for Name: familiar_relationship_type; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.familiar_relationship_type (id, name) VALUES (1, 'PADRE');
INSERT INTO public.familiar_relationship_type (id, name) VALUES (2, 'MADRE');
INSERT INTO public.familiar_relationship_type (id, name) VALUES (3, 'ABUELO');
INSERT INTO public.familiar_relationship_type (id, name) VALUES (4, 'ABUELA');
INSERT INTO public.familiar_relationship_type (id, name) VALUES (5, 'HERMANO');
INSERT INTO public.familiar_relationship_type (id, name) VALUES (6, 'HERMANA');
INSERT INTO public.familiar_relationship_type (id, name) VALUES (7, 'OTRO PARIENTE');
INSERT INTO public.familiar_relationship_type (id, name) VALUES (8, 'PERSONA QUE ASUME ACOGIMIENTO FAMILIAR');
INSERT INTO public.familiar_relationship_type (id, name) VALUES (9, 'MÁXIMA AUTORIDAD DEL CENTRO DE ACOGIDA RESIDENCIAL');
INSERT INTO public.familiar_relationship_type (id, name) VALUES (10, 'PERSONA CON PODER GENERAL O ESPECÍFICO OTORGADO POR CUALQUIERA DE LAS PERSONAS ANTES SEÑALADAS');


--
-- Data for Name: familiar_student_relationship; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.familiar_student_relationship (id, familiar_id, student_id, lives_together, familiar_relationship_type_id, isguardian) VALUES (47, 40, 39, true, 1, true);
INSERT INTO public.familiar_student_relationship (id, familiar_id, student_id, lives_together, familiar_relationship_type_id, isguardian) VALUES (48, 42, 41, true, 2, true);
INSERT INTO public.familiar_student_relationship (id, familiar_id, student_id, lives_together, familiar_relationship_type_id, isguardian) VALUES (51, 38, 37, true, 2, true);
INSERT INTO public.familiar_student_relationship (id, familiar_id, student_id, lives_together, familiar_relationship_type_id, isguardian) VALUES (52, 45, 44, true, 2, true);
INSERT INTO public.familiar_student_relationship (id, familiar_id, student_id, lives_together, familiar_relationship_type_id, isguardian) VALUES (53, 47, 46, true, 2, true);


--
-- Data for Name: familiars; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.familiars (person_id, level_of_education_id, occupation, workplace, lives) VALUES (38, 21, 'Ocupacion de prueba', 'Centro de trabajo de prueba', true);
INSERT INTO public.familiars (person_id, level_of_education_id, occupation, workplace, lives) VALUES (40, 15, 'Ocupacion de prueba', 'Centro de trabajo de prueba', true);
INSERT INTO public.familiars (person_id, level_of_education_id, occupation, workplace, lives) VALUES (42, 22, 'Ocupacion de prueba', 'Centro de trabajo de prueba', true);
INSERT INTO public.familiars (person_id, level_of_education_id, occupation, workplace, lives) VALUES (45, 12, 'Ocupacion de prueba', 'Centro de trabajo de prueba', true);
INSERT INTO public.familiars (person_id, level_of_education_id, occupation, workplace, lives) VALUES (47, 22, 'Ocupacion de prueba', 'Centro de trabajo de prueba', true);


--
-- Data for Name: genders; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.genders (id, name) VALUES (1, 'Masculino');
INSERT INTO public.genders (id, name) VALUES (2, 'Femenino');


--
-- Data for Name: grade_offering_shift_sections; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (1, 1, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (2, 1, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (3, 2, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (4, 2, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (5, 3, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (6, 3, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (7, 4, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (8, 4, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (9, 5, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (10, 5, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (11, 6, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (12, 6, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (13, 7, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (14, 7, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (15, 8, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (16, 8, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (17, 9, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (18, 9, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (19, 10, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (20, 10, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (21, 11, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (22, 11, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (23, 12, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (24, 12, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (25, 13, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (26, 13, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (27, 14, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (28, 14, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (29, 15, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (30, 15, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (31, 16, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (32, 16, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (33, 17, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (34, 17, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (35, 18, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (36, 18, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (37, 19, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (38, 19, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (39, 20, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (40, 20, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (41, 21, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (42, 21, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (43, 22, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (44, 22, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (45, 23, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (46, 23, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (47, 24, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (48, 24, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (49, 25, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (50, 25, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (51, 26, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (52, 26, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (53, 27, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (54, 27, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (55, 28, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (56, 28, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (57, 29, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (58, 29, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (59, 30, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (60, 30, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (61, 31, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (62, 31, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (63, 32, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (64, 32, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (65, 33, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (66, 33, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (67, 34, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (68, 34, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (69, 35, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (70, 35, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (71, 36, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (72, 36, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (73, 37, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (74, 37, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (75, 38, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (76, 38, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (77, 39, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (78, 39, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (79, 40, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (80, 40, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (81, 41, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (82, 41, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (83, 42, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (84, 42, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (85, 43, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (86, 43, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (87, 44, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (88, 44, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (89, 45, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (90, 45, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (91, 46, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (92, 46, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (93, 47, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (94, 47, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (95, 48, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (96, 48, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (97, 49, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (98, 49, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (99, 50, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (100, 50, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (101, 51, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (102, 51, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (103, 52, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (104, 52, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (105, 53, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (106, 53, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (107, 54, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (108, 54, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (109, 55, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (110, 55, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (111, 56, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (112, 56, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (113, 57, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (114, 57, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (115, 58, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (116, 58, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (117, 59, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (118, 59, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (119, 60, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (120, 60, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (121, 61, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (122, 61, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (123, 62, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (124, 62, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (125, 63, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (126, 63, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (127, 64, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (128, 64, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (129, 65, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (130, 65, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (131, 66, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (132, 66, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (133, 67, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (134, 67, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (135, 68, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (136, 68, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (137, 69, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (138, 69, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (139, 70, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (140, 70, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (141, 71, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (142, 71, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (143, 72, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (144, 72, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (145, 73, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (146, 73, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (147, 74, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (148, 74, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (149, 75, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (150, 75, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (151, 76, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (152, 76, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (153, 77, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (154, 77, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (155, 78, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (156, 78, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (157, 79, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (158, 79, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (159, 80, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (160, 80, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (161, 81, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (162, 81, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (163, 82, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (164, 82, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (165, 83, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (166, 83, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (167, 84, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (168, 84, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (169, 85, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (170, 85, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (171, 86, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (172, 86, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (173, 87, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (174, 87, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (175, 88, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (176, 88, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (177, 89, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (178, 89, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (179, 90, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (180, 90, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (181, 91, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (182, 91, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (183, 92, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (184, 92, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (185, 93, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (186, 93, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (187, 94, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (188, 94, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (189, 95, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (190, 95, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (191, 96, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (192, 96, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (193, 97, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (194, 97, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (195, 98, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (196, 98, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (197, 99, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (198, 99, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (199, 100, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (200, 100, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (201, 101, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (202, 101, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (203, 102, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (204, 102, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (205, 103, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (206, 103, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (207, 104, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (208, 104, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (209, 105, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (210, 105, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (211, 106, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (212, 106, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (213, 107, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (214, 107, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (215, 108, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (216, 108, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (217, 109, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (218, 109, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (219, 110, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (220, 110, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (221, 111, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (222, 111, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (223, 112, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (224, 112, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (225, 113, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (226, 113, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (227, 114, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (228, 114, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (229, 115, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (230, 115, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (231, 116, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (232, 116, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (233, 117, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (234, 117, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (235, 118, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (236, 118, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (237, 119, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (238, 119, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (239, 120, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (240, 120, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (241, 121, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (242, 121, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (243, 122, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (244, 122, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (245, 123, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (246, 123, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (247, 124, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (248, 124, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (249, 125, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (250, 125, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (251, 126, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (252, 126, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (253, 127, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (254, 127, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (255, 128, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (256, 128, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (257, 129, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (258, 129, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (259, 130, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (260, 130, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (261, 131, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (262, 131, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (263, 132, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (264, 132, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (265, 133, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (266, 133, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (267, 134, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (268, 134, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (269, 135, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (270, 135, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (271, 136, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (272, 136, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (273, 137, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (274, 137, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (275, 138, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (276, 138, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (277, 139, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (278, 139, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (279, 140, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (280, 140, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (281, 141, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (282, 141, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (283, 142, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (284, 142, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (285, 143, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (286, 143, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (287, 144, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (288, 144, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (289, 145, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (290, 145, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (291, 146, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (292, 146, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (293, 147, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (294, 147, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (295, 148, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (296, 148, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (297, 149, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (298, 149, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (299, 150, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (300, 150, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (301, 151, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (302, 151, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (303, 152, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (304, 152, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (305, 153, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (306, 153, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (307, 154, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (308, 154, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (309, 155, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (310, 155, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (311, 156, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (312, 156, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (313, 157, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (314, 157, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (315, 158, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (316, 158, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (317, 159, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (318, 159, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (319, 160, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (320, 160, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (321, 161, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (322, 161, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (323, 162, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (324, 162, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (325, 163, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (326, 163, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (327, 164, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (328, 164, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (329, 165, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (330, 165, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (331, 166, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (332, 166, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (333, 167, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (334, 167, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (335, 168, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (336, 168, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (337, 169, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (338, 169, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (339, 170, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (340, 170, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (341, 171, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (342, 171, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (343, 172, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (344, 172, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (345, 173, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (346, 173, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (347, 174, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (348, 174, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (349, 175, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (350, 175, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (351, 176, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (352, 176, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (353, 177, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (354, 177, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (355, 178, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (356, 178, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (357, 179, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (358, 179, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (359, 180, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (360, 180, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (361, 181, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (362, 181, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (363, 182, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (364, 182, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (365, 183, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (366, 183, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (367, 184, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (368, 184, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (369, 185, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (370, 185, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (371, 186, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (372, 186, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (373, 187, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (374, 187, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (375, 188, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (376, 188, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (377, 189, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (378, 189, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (379, 190, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (380, 190, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (381, 191, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (382, 191, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (383, 192, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (384, 192, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (385, 193, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (386, 193, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (387, 194, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (388, 194, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (389, 195, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (390, 195, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (391, 196, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (392, 196, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (393, 197, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (394, 197, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (395, 198, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (396, 198, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (397, 199, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (398, 199, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (399, 200, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (400, 200, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (401, 201, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (402, 201, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (403, 202, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (404, 202, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (405, 203, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (406, 203, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (407, 204, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (408, 204, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (409, 205, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (410, 205, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (411, 206, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (412, 206, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (413, 207, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (414, 207, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (415, 208, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (416, 208, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (417, 209, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (418, 209, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (419, 210, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (420, 210, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (421, 211, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (422, 211, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (423, 212, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (424, 212, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (425, 213, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (426, 213, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (427, 214, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (428, 214, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (429, 215, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (430, 215, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (431, 216, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (432, 216, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (433, 217, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (434, 217, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (435, 218, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (436, 218, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (437, 219, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (438, 219, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (439, 220, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (440, 220, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (441, 221, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (442, 221, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (443, 222, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (444, 222, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (445, 223, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (446, 223, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (447, 224, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (448, 224, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (449, 225, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (450, 225, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (451, 226, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (452, 226, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (453, 227, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (454, 227, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (455, 228, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (456, 228, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (457, 229, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (458, 229, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (459, 230, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (460, 230, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (461, 231, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (462, 231, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (463, 232, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (464, 232, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (465, 233, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (466, 233, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (467, 234, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (468, 234, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (469, 235, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (470, 235, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (471, 236, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (472, 236, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (473, 237, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (474, 237, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (475, 238, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (476, 238, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (481, 241, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (482, 241, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (483, 242, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (484, 242, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (489, 245, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (490, 245, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (491, 246, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (492, 246, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (507, 251, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (508, 251, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (509, 251, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (510, 251, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (511, 252, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (512, 252, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (513, 252, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (514, 252, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (531, 255, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (532, 255, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (533, 255, 'C', 3);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (534, 256, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (535, 256, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (536, 256, 'C', 3);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (537, 256, 'D', 4);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (538, 257, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (539, 257, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (540, 257, 'C', 3);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (541, 257, 'D', 4);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (542, 257, 'E', 5);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (543, 257, 'F', 6);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (544, 258, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (545, 258, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (546, 258, 'C', 3);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (547, 258, 'D', 4);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (548, 258, 'E', 5);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (549, 258, 'F', 6);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (550, 258, 'G', 7);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (551, 258, 'H', 8);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (552, 259, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (553, 259, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (554, 259, 'C', 3);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (555, 259, 'D', 4);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (556, 259, 'E', 5);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (557, 260, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (558, 260, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (559, 260, 'C', 3);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (560, 260, 'D', 4);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (561, 260, 'E', 5);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (562, 260, 'F', 6);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (563, 260, 'G', 7);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (564, 260, 'H', 8);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (565, 260, 'I', 9);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (566, 261, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (567, 261, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (568, 261, 'C', 3);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (569, 261, 'D', 4);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (570, 261, 'E', 5);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (571, 261, 'F', 6);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (572, 261, 'G', 7);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (573, 261, 'H', 8);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (574, 261, 'I', 9);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (585, 263, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (586, 263, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (587, 263, 'C', 3);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (588, 263, 'D', 4);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (589, 263, 'E', 5);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (590, 263, 'F', 6);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (591, 264, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (592, 264, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (593, 264, 'C', 3);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (594, 264, 'D', 4);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (595, 264, 'E', 5);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (596, 264, 'F', 6);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (597, 264, 'G', 7);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (598, 264, 'H', 8);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (599, 264, 'I', 9);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (600, 265, 'A', 1);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (601, 265, 'B', 2);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (602, 265, 'C', 3);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (603, 265, 'D', 4);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (604, 265, 'E', 5);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (605, 265, 'F', 6);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (606, 265, 'G', 7);
INSERT INTO public.grade_offering_shift_sections (id, grade_offering_shift_id, section, section_number) VALUES (607, 265, 'H', 8);


--
-- Data for Name: grade_offering_shifts; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (52, 52, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (53, 53, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (54, 54, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (55, 55, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (56, 56, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (57, 57, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (58, 58, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (59, 59, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (60, 60, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (61, 61, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (62, 62, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (63, 63, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (64, 64, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (65, 65, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (66, 66, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (67, 67, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (68, 68, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (69, 69, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (70, 70, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (71, 71, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (72, 72, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (73, 73, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (74, 74, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (75, 75, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (76, 76, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (77, 77, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (78, 78, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (79, 79, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (80, 80, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (81, 81, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (82, 82, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (83, 83, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (84, 84, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (85, 85, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (86, 86, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (87, 87, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (88, 88, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (89, 89, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (90, 90, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (91, 91, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (92, 92, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (93, 93, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (94, 94, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (95, 95, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (96, 96, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (97, 97, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (98, 98, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (99, 99, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (100, 100, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (101, 101, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (102, 102, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (103, 103, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (104, 104, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (105, 105, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (123, 123, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (124, 124, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (125, 125, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (126, 126, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (127, 127, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (128, 128, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (129, 129, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (130, 130, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (131, 131, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (132, 132, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (133, 133, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (134, 134, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (135, 135, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (136, 136, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (137, 137, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (138, 138, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (139, 139, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (140, 140, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (141, 141, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (142, 142, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (143, 143, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (144, 144, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (145, 145, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (146, 146, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (147, 147, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (148, 148, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (149, 149, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (150, 150, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (151, 151, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (152, 152, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (153, 153, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (154, 154, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (155, 155, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (156, 156, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (157, 157, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (158, 158, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (159, 159, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (160, 160, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (161, 161, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (162, 162, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (163, 163, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (164, 164, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (165, 165, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (166, 166, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (167, 167, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (168, 168, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (169, 169, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (170, 170, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (171, 171, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (172, 172, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (173, 173, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (174, 174, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (175, 175, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (176, 176, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (177, 177, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (178, 178, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (179, 179, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (180, 180, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (181, 181, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (182, 182, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (183, 183, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (184, 184, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (185, 185, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (186, 186, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (187, 187, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (188, 188, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (189, 189, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (190, 190, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (191, 191, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (192, 192, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (193, 193, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (194, 194, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (195, 195, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (196, 196, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (197, 197, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (198, 198, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (199, 199, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (200, 200, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (201, 201, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (202, 202, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (203, 203, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (204, 204, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (205, 205, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (206, 206, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (207, 207, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (208, 208, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (209, 209, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (210, 210, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (211, 211, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (212, 212, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (213, 213, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (214, 214, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (215, 215, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (216, 216, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (217, 217, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (218, 218, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (219, 219, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (220, 220, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (221, 221, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (222, 222, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (223, 223, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (224, 224, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (225, 225, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (1, 1, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (2, 2, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (3, 3, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (4, 4, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (5, 5, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (6, 6, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (7, 7, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (8, 8, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (9, 9, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (10, 10, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (11, 11, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (12, 12, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (13, 13, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (14, 14, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (15, 15, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (16, 16, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (17, 17, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (18, 18, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (19, 19, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (20, 20, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (21, 21, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (22, 22, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (23, 23, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (24, 24, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (25, 25, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (26, 26, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (27, 27, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (28, 28, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (29, 29, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (30, 30, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (31, 31, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (32, 32, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (33, 33, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (34, 34, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (35, 35, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (36, 36, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (37, 37, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (38, 38, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (39, 39, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (40, 40, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (41, 41, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (42, 42, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (43, 43, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (44, 44, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (45, 45, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (46, 46, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (47, 47, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (48, 48, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (49, 49, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (50, 50, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (51, 51, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (252, 150, 2, 2);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (255, 239, 3, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (256, 240, 4, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (258, 188, 8, 2);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (259, 241, 5, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (261, 243, 9, 2);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (265, 245, 8, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (251, 133, 2, 2);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (257, 240, 6, 2);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (260, 242, 9, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (263, 244, 6, 2);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (106, 106, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (107, 107, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (108, 108, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (109, 109, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (110, 110, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (111, 111, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (112, 112, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (113, 113, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (114, 114, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (115, 115, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (116, 116, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (117, 117, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (118, 118, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (119, 119, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (120, 120, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (121, 121, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (122, 122, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (226, 226, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (227, 227, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (228, 228, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (229, 229, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (230, 230, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (231, 231, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (232, 232, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (233, 233, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (234, 234, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (235, 235, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (236, 236, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (237, 237, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (238, 238, 2, 1);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (241, 84, 2, 2);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (242, 85, 2, 2);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (245, 101, 2, 2);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (246, 102, 2, 2);
INSERT INTO public.grade_offering_shifts (id, grade_offering_id, sections, shift_id) VALUES (264, 244, 9, 1);


--
-- Data for Name: grade_offerings; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (1, 1, 1);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (2, 1, 2);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (3, 1, 3);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (4, 1, 4);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (5, 1, 5);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (6, 1, 6);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (7, 1, 7);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (8, 1, 8);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (9, 1, 9);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (10, 1, 10);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (11, 1, 11);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (12, 1, 12);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (13, 1, 13);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (14, 1, 14);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (15, 1, 15);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (16, 1, 16);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (17, 1, 17);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (18, 2, 1);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (19, 2, 2);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (20, 2, 3);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (21, 2, 4);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (22, 2, 5);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (23, 2, 6);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (24, 2, 7);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (25, 2, 8);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (26, 2, 9);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (27, 2, 10);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (28, 2, 11);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (29, 2, 12);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (30, 2, 13);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (31, 2, 14);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (32, 2, 15);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (33, 2, 16);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (34, 2, 17);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (35, 3, 1);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (36, 3, 2);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (37, 3, 3);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (38, 3, 4);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (39, 3, 5);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (40, 3, 6);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (41, 3, 7);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (42, 3, 8);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (43, 3, 9);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (44, 3, 10);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (45, 3, 11);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (46, 3, 12);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (47, 3, 13);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (48, 3, 14);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (49, 3, 15);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (50, 3, 16);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (51, 3, 17);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (52, 4, 1);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (53, 4, 2);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (54, 4, 3);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (55, 4, 4);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (56, 4, 5);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (57, 4, 6);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (58, 4, 7);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (59, 4, 8);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (60, 4, 9);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (61, 4, 10);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (62, 4, 11);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (63, 4, 12);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (64, 4, 13);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (65, 4, 14);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (66, 4, 15);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (67, 4, 16);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (68, 4, 17);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (69, 5, 1);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (70, 5, 2);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (71, 5, 3);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (72, 5, 4);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (73, 5, 5);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (74, 5, 6);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (75, 5, 7);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (76, 5, 8);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (77, 5, 9);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (78, 5, 10);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (79, 5, 11);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (80, 5, 12);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (81, 5, 13);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (82, 5, 14);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (83, 5, 15);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (84, 5, 16);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (85, 5, 17);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (86, 6, 1);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (87, 6, 2);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (88, 6, 3);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (89, 6, 4);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (90, 6, 5);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (91, 6, 6);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (92, 6, 7);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (93, 6, 8);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (94, 6, 9);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (95, 6, 10);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (96, 6, 11);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (97, 6, 12);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (98, 6, 13);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (99, 6, 14);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (100, 6, 15);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (101, 6, 16);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (102, 6, 17);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (103, 7, 1);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (104, 7, 2);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (105, 7, 3);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (106, 7, 4);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (107, 7, 5);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (108, 7, 6);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (109, 7, 7);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (110, 7, 8);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (111, 7, 9);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (112, 7, 10);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (113, 7, 11);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (114, 7, 12);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (115, 7, 13);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (116, 7, 14);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (117, 7, 15);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (118, 7, 16);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (119, 7, 17);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (120, 8, 1);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (121, 8, 2);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (122, 8, 3);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (123, 8, 4);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (124, 8, 5);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (125, 8, 6);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (126, 8, 7);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (127, 8, 8);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (128, 8, 9);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (129, 8, 10);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (130, 8, 11);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (131, 8, 12);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (132, 8, 13);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (133, 8, 14);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (134, 8, 15);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (135, 8, 16);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (136, 8, 17);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (137, 9, 1);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (138, 9, 2);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (139, 9, 3);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (140, 9, 4);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (141, 9, 5);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (142, 9, 6);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (143, 9, 7);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (144, 9, 8);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (145, 9, 9);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (146, 9, 10);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (147, 9, 11);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (148, 9, 12);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (149, 9, 13);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (150, 9, 14);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (151, 9, 15);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (152, 9, 16);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (153, 9, 17);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (154, 10, 1);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (155, 10, 2);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (156, 10, 3);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (157, 10, 4);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (158, 10, 5);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (159, 10, 6);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (160, 10, 7);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (161, 10, 8);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (162, 10, 9);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (163, 10, 10);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (164, 10, 11);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (165, 10, 12);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (166, 10, 13);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (167, 10, 14);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (168, 10, 15);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (169, 10, 16);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (170, 10, 17);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (171, 11, 1);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (172, 11, 2);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (173, 11, 3);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (174, 11, 4);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (175, 11, 5);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (176, 11, 6);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (177, 11, 7);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (178, 11, 8);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (179, 11, 9);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (180, 11, 10);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (181, 11, 11);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (182, 11, 12);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (183, 11, 13);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (184, 11, 14);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (185, 11, 15);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (186, 11, 16);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (187, 11, 17);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (188, 12, 1);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (189, 12, 2);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (190, 12, 3);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (191, 12, 4);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (192, 12, 5);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (193, 12, 6);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (194, 12, 7);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (195, 12, 8);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (196, 12, 9);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (197, 12, 10);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (198, 12, 11);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (199, 12, 12);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (200, 12, 13);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (201, 12, 14);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (202, 12, 15);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (203, 12, 16);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (204, 12, 17);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (205, 13, 1);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (206, 13, 2);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (207, 13, 3);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (208, 13, 4);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (209, 13, 5);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (210, 13, 6);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (211, 13, 7);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (212, 13, 8);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (213, 13, 9);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (214, 13, 10);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (215, 13, 11);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (216, 13, 12);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (217, 13, 13);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (218, 13, 14);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (219, 13, 15);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (220, 13, 16);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (221, 13, 17);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (222, 14, 1);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (223, 14, 2);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (224, 14, 3);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (225, 14, 4);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (226, 14, 5);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (227, 14, 6);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (228, 14, 7);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (229, 14, 8);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (230, 14, 9);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (231, 14, 10);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (232, 14, 11);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (233, 14, 12);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (234, 14, 13);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (235, 14, 14);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (236, 14, 15);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (237, 14, 16);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (238, 14, 17);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (239, 14, 18);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (240, 14, 19);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (241, 12, 19);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (242, 14, 20);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (243, 13, 20);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (244, 14, 21);
INSERT INTO public.grade_offerings (id, grade_id, school_year_id) VALUES (245, 1, 22);


--
-- Data for Name: grades; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.grades (id, level_id, name, year) VALUES (1, 1, '3 años', 3);
INSERT INTO public.grades (id, level_id, name, year) VALUES (2, 1, '4 años', 4);
INSERT INTO public.grades (id, level_id, name, year) VALUES (3, 1, '5 años', 5);
INSERT INTO public.grades (id, level_id, name, year) VALUES (4, 2, '1° grado', 1);
INSERT INTO public.grades (id, level_id, name, year) VALUES (5, 2, '2° grado', 2);
INSERT INTO public.grades (id, level_id, name, year) VALUES (6, 2, '3° grado', 3);
INSERT INTO public.grades (id, level_id, name, year) VALUES (7, 2, '4° grado', 4);
INSERT INTO public.grades (id, level_id, name, year) VALUES (8, 2, '5° grado', 5);
INSERT INTO public.grades (id, level_id, name, year) VALUES (9, 2, '6° grado', 6);
INSERT INTO public.grades (id, level_id, name, year) VALUES (10, 3, '1° año', 1);
INSERT INTO public.grades (id, level_id, name, year) VALUES (11, 3, '2° año', 2);
INSERT INTO public.grades (id, level_id, name, year) VALUES (12, 3, '3° año', 3);
INSERT INTO public.grades (id, level_id, name, year) VALUES (13, 3, '4° año', 4);
INSERT INTO public.grades (id, level_id, name, year) VALUES (14, 3, '5° año', 5);


--
-- Data for Name: institution; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.institution (id, name, ruc, ruc_state_id) VALUES (2, 'SERVICIOS EDUCATIVOS SANTA RITA DE JESUS', '20602648568', 4);
INSERT INTO public.institution (id, name, ruc, ruc_state_id) VALUES (3, 'SRJ EDUCA SAC', '20611732385', 1);
INSERT INTO public.institution (id, name, ruc, ruc_state_id) VALUES (1, 'SRJ SERVICIOS EDUCATIVOS', '20602735363', 4);


--
-- Data for Name: institution_levels; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.institution_levels (level_id, institution_id, is_active, start_date, end_date) VALUES (1, 2, false, '2010-01-01', '2024-12-31');
INSERT INTO public.institution_levels (level_id, institution_id, is_active, start_date, end_date) VALUES (2, 2, false, '2010-01-01', '2024-12-31');
INSERT INTO public.institution_levels (level_id, institution_id, is_active, start_date, end_date) VALUES (3, 1, false, '2010-01-01', '2024-12-31');
INSERT INTO public.institution_levels (level_id, institution_id, is_active, start_date, end_date) VALUES (1, 3, true, '2010-01-01', NULL);
INSERT INTO public.institution_levels (level_id, institution_id, is_active, start_date, end_date) VALUES (2, 3, true, '2010-01-01', NULL);
INSERT INTO public.institution_levels (level_id, institution_id, is_active, start_date, end_date) VALUES (3, 3, true, '2010-01-01', NULL);


--
-- Data for Name: job_positions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.job_positions (id, name) VALUES (1, 'Director');
INSERT INTO public.job_positions (id, name) VALUES (2, 'Profesor(a) de Aula');
INSERT INTO public.job_positions (id, name) VALUES (3, 'Profesor(a) Coordinador(a)');
INSERT INTO public.job_positions (id, name) VALUES (4, 'Profesor(a)');
INSERT INTO public.job_positions (id, name) VALUES (5, 'Auxiliar');
INSERT INTO public.job_positions (id, name) VALUES (6, 'Profesor(a) de Música');
INSERT INTO public.job_positions (id, name) VALUES (7, 'Profesor(a) de Danza');
INSERT INTO public.job_positions (id, name) VALUES (8, 'Profesor(a) de Artes Plásticas');
INSERT INTO public.job_positions (id, name) VALUES (9, 'Portero');
INSERT INTO public.job_positions (id, name) VALUES (10, 'Contador(a)');
INSERT INTO public.job_positions (id, name) VALUES (11, 'Profesor(a) Educación Física');
INSERT INTO public.job_positions (id, name) VALUES (12, 'Profesor(a) Inglés');
INSERT INTO public.job_positions (id, name) VALUES (13, 'Asistente de Contabilidad');
INSERT INTO public.job_positions (id, name) VALUES (14, 'Profesor(a) de Cómputo');
INSERT INTO public.job_positions (id, name) VALUES (15, 'Psicóloga');
INSERT INTO public.job_positions (id, name) VALUES (16, 'Guardián');
INSERT INTO public.job_positions (id, name) VALUES (17, 'Asistente de Administración2');
INSERT INTO public.job_positions (id, name) VALUES (18, 'Cocinera');
INSERT INTO public.job_positions (id, name) VALUES (19, 'Contador(a) Externo(a)');
INSERT INTO public.job_positions (id, name) VALUES (20, 'Asistente de Aula');
INSERT INTO public.job_positions (id, name) VALUES (21, 'Profesor(a) por horas');
INSERT INTO public.job_positions (id, name) VALUES (22, 'Mantenimiento');
INSERT INTO public.job_positions (id, name) VALUES (23, 'Recepción');
INSERT INTO public.job_positions (id, name) VALUES (24, 'Psicologo');
INSERT INTO public.job_positions (id, name) VALUES (25, 'Asesora');
INSERT INTO public.job_positions (id, name) VALUES (26, 'Asistente Contable');
INSERT INTO public.job_positions (id, name) VALUES (27, 'Sub Directora');
INSERT INTO public.job_positions (id, name) VALUES (28, 'Caja');


--
-- Data for Name: languages; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.languages (id, name) VALUES (1, 'Español');
INSERT INTO public.languages (id, name) VALUES (2, 'Portugués');
INSERT INTO public.languages (id, name) VALUES (3, 'Quechua');
INSERT INTO public.languages (id, name) VALUES (4, 'Guaraní');
INSERT INTO public.languages (id, name) VALUES (5, 'Náhuatl');
INSERT INTO public.languages (id, name) VALUES (6, 'Aymara');
INSERT INTO public.languages (id, name) VALUES (7, 'Lenguas mayas');
INSERT INTO public.languages (id, name) VALUES (8, 'Mapudungún');
INSERT INTO public.languages (id, name) VALUES (9, 'Wayú');
INSERT INTO public.languages (id, name) VALUES (10, 'Lenguas criollas');
INSERT INTO public.languages (id, name) VALUES (11, 'Inglés');
INSERT INTO public.languages (id, name) VALUES (12, 'Francés');
INSERT INTO public.languages (id, name) VALUES (13, 'Italiano');
INSERT INTO public.languages (id, name) VALUES (14, 'Alemán');
INSERT INTO public.languages (id, name) VALUES (15, 'Neerlandés');
INSERT INTO public.languages (id, name) VALUES (16, 'Catalán');
INSERT INTO public.languages (id, name) VALUES (17, 'Gallego');
INSERT INTO public.languages (id, name) VALUES (18, 'Euskera');
INSERT INTO public.languages (id, name) VALUES (19, 'Griego');
INSERT INTO public.languages (id, name) VALUES (20, 'Polaco');
INSERT INTO public.languages (id, name) VALUES (21, 'Ruso');
INSERT INTO public.languages (id, name) VALUES (22, 'Sueco');
INSERT INTO public.languages (id, name) VALUES (23, 'Danés');
INSERT INTO public.languages (id, name) VALUES (24, 'Noruego');
INSERT INTO public.languages (id, name) VALUES (25, 'Finlandés');
INSERT INTO public.languages (id, name) VALUES (26, 'Checo');
INSERT INTO public.languages (id, name) VALUES (27, 'Húngaro');
INSERT INTO public.languages (id, name) VALUES (28, 'Rumano');
INSERT INTO public.languages (id, name) VALUES (29, 'Búlgaro');
INSERT INTO public.languages (id, name) VALUES (30, 'Serbio');
INSERT INTO public.languages (id, name) VALUES (31, 'Croata');
INSERT INTO public.languages (id, name) VALUES (32, 'Bosnio');
INSERT INTO public.languages (id, name) VALUES (33, 'Albanés');
INSERT INTO public.languages (id, name) VALUES (34, 'Turco');
INSERT INTO public.languages (id, name) VALUES (35, 'Lengua de señas');


--
-- Data for Name: level_of_education; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.level_of_education (id, name) VALUES (12, 'Sin instrucción');
INSERT INTO public.level_of_education (id, name) VALUES (13, 'Inicial');
INSERT INTO public.level_of_education (id, name) VALUES (14, 'Primaria incompleta');
INSERT INTO public.level_of_education (id, name) VALUES (15, 'Primaria completa');
INSERT INTO public.level_of_education (id, name) VALUES (16, 'Secundaria incompleta');
INSERT INTO public.level_of_education (id, name) VALUES (17, 'Secundaria completa');
INSERT INTO public.level_of_education (id, name) VALUES (18, 'Superior técnica incompleta');
INSERT INTO public.level_of_education (id, name) VALUES (19, 'Superior técnica completa');
INSERT INTO public.level_of_education (id, name) VALUES (20, 'Superior universitaria incompleta');
INSERT INTO public.level_of_education (id, name) VALUES (21, 'Superior universitaria completa');
INSERT INTO public.level_of_education (id, name) VALUES (22, 'Postgrado');


--
-- Data for Name: levels; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.levels (id, name, order_index) VALUES (1, 'Inicial', 0);
INSERT INTO public.levels (id, name, order_index) VALUES (2, 'Primaria', 1);
INSERT INTO public.levels (id, name, order_index) VALUES (3, 'Secundaria', 2);


--
-- Data for Name: lunch_assignments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (1, NULL, 37, 1, '2026-06-12', 0.00, 3, false, true, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (2, NULL, 37, 2, '2026-06-12', 3.00, 3, false, true, 3.00, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (3, NULL, 37, 3, '2026-06-12', 2.50, 3, false, true, 2.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (4, NULL, 37, 4, '2026-06-12', 3.50, 3, false, true, 3.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (5, NULL, 37, 1, '2026-06-12', 0.00, 3, false, true, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (6, NULL, 37, 2, '2026-06-12', 3.00, 3, false, true, 3.00, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (7, NULL, 37, 3, '2026-06-12', 2.50, 3, false, true, 2.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (8, NULL, 37, 4, '2026-06-12', 3.50, 3, false, true, 3.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (9, NULL, 37, 1, '2026-06-12', 0.00, 3, false, true, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (10, NULL, 37, 2, '2026-06-12', 3.00, 3, false, true, 3.00, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (11, NULL, 37, 3, '2026-06-12', 2.50, 3, false, true, 2.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (12, NULL, 37, 4, '2026-06-12', 3.50, 3, false, true, 3.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (13, NULL, 37, 1, '2026-06-12', 0.00, 3, false, true, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (14, NULL, 37, 2, '2026-06-12', 3.00, 3, false, true, 3.00, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (15, NULL, 37, 3, '2026-06-12', 2.50, 3, false, true, 2.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (16, NULL, 37, 4, '2026-06-12', 3.50, 3, false, true, 3.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (17, NULL, 37, 1, '2026-06-12', 0.00, 3, false, true, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (18, NULL, 37, 2, '2026-06-12', 3.00, 3, false, true, 3.00, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (19, NULL, 37, 3, '2026-06-12', 2.50, 3, false, true, 2.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (20, NULL, 37, 4, '2026-06-12', 3.50, 3, false, true, 3.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (21, NULL, 37, 1, '2026-06-12', 0.00, 3, false, true, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (22, NULL, 37, 2, '2026-06-12', 3.00, 3, false, true, 3.00, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (23, NULL, 37, 3, '2026-06-12', 2.50, 3, false, true, 2.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (24, NULL, 37, 4, '2026-06-12', 3.50, 3, false, true, 3.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (25, NULL, 37, 1, '2026-06-12', 0.00, 3, false, true, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (26, NULL, 37, 2, '2026-06-12', 3.00, 3, false, true, 3.00, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (27, NULL, 37, 3, '2026-06-12', 2.50, 3, false, true, 2.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (28, NULL, 37, 4, '2026-06-12', 3.50, 3, false, true, 3.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (29, NULL, 37, 1, '2026-06-12', 0.00, 3, false, true, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (30, NULL, 37, 2, '2026-06-12', 3.00, 3, false, true, 3.00, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (31, NULL, 37, 3, '2026-06-12', 2.50, 3, false, true, 2.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (32, NULL, 37, 4, '2026-06-12', 3.50, 3, false, true, 3.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (33, NULL, 39, 3, '2026-06-12', 2.50, 3, false, true, 2.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (34, NULL, 39, 9, '2026-06-12', 3.50, 3, false, true, 3.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (35, NULL, 39, 22, '2026-06-12', 3.00, 3, false, true, 3.00, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (36, NULL, 39, 75, '2026-06-12', 3.50, 3, false, true, 3.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (37, NULL, 39, 71, '2026-06-12', 3.50, 3, false, true, 3.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (38, NULL, 39, 47, '2026-06-13', 3.50, 3, false, true, 3.50, '2026-06-13', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (39, NULL, 39, 48, '2026-06-13', 3.50, 3, false, true, 3.50, '2026-06-13', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (40, NULL, 39, 49, '2026-06-13', 3.50, 3, false, true, 3.50, '2026-06-13', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (41, NULL, 39, 50, '2026-06-13', 0.00, 3, false, true, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (42, NULL, 39, 51, '2026-06-13', 1.50, 3, false, true, 1.50, '2026-06-13', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (43, NULL, 39, 52, '2026-06-13', 3.00, 3, false, true, 3.00, '2026-06-13', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (44, NULL, 39, 53, '2026-06-13', 3.00, 3, false, true, 3.00, '2026-06-13', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (45, NULL, 39, 54, '2026-06-13', 3.50, 3, false, true, 3.50, '2026-06-13', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (46, NULL, 39, 55, '2026-06-13', 3.50, 3, false, true, 3.50, '2026-06-13', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (47, NULL, 39, 56, '2026-06-13', 1.00, 3, false, true, 1.00, '2026-06-13', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (48, NULL, 39, 57, '2026-06-13', 3.50, 3, false, true, 3.50, '2026-06-13', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (49, NULL, 39, 58, '2026-06-13', 3.50, 3, false, true, 3.50, '2026-06-13', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (50, NULL, 37, 1, '2026-06-15', 0.00, 3, false, true, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (51, NULL, 37, 2, '2026-06-15', 3.00, 3, true, true, 3.00, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (52, NULL, 37, 3, '2026-06-15', 2.50, 3, true, true, 2.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (53, NULL, 37, 12, '2026-06-15', 3.50, 3, true, true, 3.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (54, NULL, 37, 8, '2026-07-19', 3.50, 3, false, true, 3.50, '2026-07-19', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (55, NULL, 37, 10, '2026-07-19', 3.50, 3, false, true, 3.50, '2026-07-19', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (56, NULL, 37, 15, '2026-07-19', 3.50, 3, false, true, 3.50, '2026-07-19', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (57, NULL, 37, 72, '2026-07-19', 1.00, 3, false, true, 1.00, '2026-07-19', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (58, NULL, 37, 74, '2026-07-19', 3.00, 3, false, true, 3.00, '2026-07-19', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (59, NULL, 37, 6, '2026-06-12', 3.50, 3, false, true, 3.50, '2026-06-12', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (60, NULL, 44, 1, '2026-06-14', 0.00, 3, false, true, NULL, NULL, 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (76, NULL, 44, 16, '2026-06-14', 0.00, 3, false, true, NULL, NULL, 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (61, NULL, 44, 2, '2026-06-14', 3.00, 3, true, true, 3.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (62, NULL, 44, 3, '2026-06-14', 2.50, 3, true, true, 2.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (63, NULL, 44, 4, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (93, NULL, 44, 33, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (94, NULL, 44, 35, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (95, NULL, 44, 36, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (96, NULL, 44, 37, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (97, NULL, 44, 38, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (98, NULL, 44, 39, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (99, NULL, 44, 40, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (100, NULL, 44, 41, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (101, NULL, 44, 42, '2026-06-14', 1.00, 3, true, true, 1.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (104, NULL, 44, 45, '2026-06-14', 0.00, 3, false, true, NULL, NULL, 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (109, NULL, 44, 50, '2026-06-14', 0.00, 3, false, true, NULL, NULL, 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (137, NULL, 44, 78, '2026-06-14', 0.50, 3, true, false, NULL, NULL, 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (138, NULL, 44, 79, '2026-06-14', 0.50, 3, true, false, NULL, NULL, 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (139, NULL, 44, 80, '2026-06-14', 0.50, 3, true, false, NULL, NULL, 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (140, NULL, 44, 81, '2026-06-14', 3.50, 3, true, false, NULL, NULL, 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (141, NULL, 44, 82, '2026-06-14', 3.50, 3, true, false, NULL, NULL, 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (144, NULL, 39, 4, '2026-06-13', 3.50, 3, true, false, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (145, NULL, 39, 5, '2026-06-13', 3.50, 3, true, false, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (146, NULL, 39, 6, '2026-06-13', 3.50, 3, true, false, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (64, NULL, 44, 5, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (65, NULL, 44, 6, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (66, NULL, 44, 7, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (67, NULL, 44, 8, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (68, NULL, 44, 9, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (69, NULL, 44, 10, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (70, NULL, 44, 11, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (71, NULL, 44, 12, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (72, NULL, 44, 13, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (73, NULL, 44, 14, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (74, NULL, 44, 15, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (75, NULL, 44, 17, '2026-06-14', 3.00, 3, true, true, 3.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (77, NULL, 44, 18, '2026-06-14', 3.00, 3, true, true, 3.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (78, NULL, 44, 20, '2026-06-14', 3.00, 3, true, true, 3.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (79, NULL, 44, 19, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (80, NULL, 44, 21, '2026-06-14', 3.00, 3, true, true, 3.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (81, NULL, 44, 22, '2026-06-14', 3.00, 3, true, true, 3.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (82, NULL, 44, 23, '2026-06-14', 3.00, 3, true, true, 3.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (83, NULL, 44, 24, '2026-06-14', 3.00, 3, true, true, 3.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (84, NULL, 44, 25, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (85, NULL, 44, 26, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (86, NULL, 44, 28, '2026-06-14', 2.50, 3, true, true, 2.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (87, NULL, 44, 27, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (88, NULL, 44, 29, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (89, NULL, 44, 30, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (90, NULL, 44, 31, '2026-06-14', 3.00, 3, true, true, 3.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (91, NULL, 44, 32, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (92, NULL, 44, 34, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (102, NULL, 44, 44, '2026-06-14', 1.50, 3, true, true, 1.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (103, NULL, 44, 43, '2026-06-14', 1.00, 3, true, true, 1.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (105, NULL, 44, 46, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (106, NULL, 44, 47, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (107, NULL, 44, 48, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (108, NULL, 44, 49, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (110, NULL, 44, 51, '2026-06-14', 1.50, 3, true, true, 1.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (111, NULL, 44, 52, '2026-06-14', 3.00, 3, true, true, 3.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (112, NULL, 44, 54, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (113, NULL, 44, 53, '2026-06-14', 3.00, 3, true, true, 3.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (114, NULL, 44, 55, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (115, NULL, 44, 56, '2026-06-14', 1.00, 3, true, true, 1.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (116, NULL, 44, 57, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (117, NULL, 44, 58, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (118, NULL, 44, 59, '2026-06-14', 0.50, 3, true, true, 0.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (119, NULL, 44, 60, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (120, NULL, 44, 62, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (121, NULL, 44, 61, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (122, NULL, 44, 63, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (123, NULL, 44, 65, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (124, NULL, 44, 64, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (125, NULL, 44, 67, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (126, NULL, 44, 66, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (127, NULL, 44, 68, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (128, NULL, 44, 69, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (129, NULL, 44, 71, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (150, NULL, 37, 3, '2026-06-17', 2.50, 3, false, true, 2.50, '2026-06-17', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (130, NULL, 44, 70, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (131, NULL, 44, 72, '2026-06-14', 1.00, 3, true, true, 1.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (132, NULL, 44, 73, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (133, NULL, 44, 74, '2026-06-14', 3.00, 3, true, true, 3.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (134, NULL, 44, 76, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (135, NULL, 44, 75, '2026-06-14', 3.50, 3, true, true, 3.50, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (136, NULL, 44, 77, '2026-06-14', 3.50, 3, true, false, 3.00, '2026-06-13', 2);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (151, NULL, 37, 4, '2026-06-17', 3.50, 3, false, true, 3.50, '2026-06-17', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (142, NULL, 37, 4, '2026-06-13', 3.50, 3, true, true, 3.50, '2026-06-15', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (147, NULL, 43, 3, '2026-06-15', 2.50, 3, true, false, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (148, NULL, 43, 2, '2026-06-15', 3.00, 3, true, false, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (149, NULL, 43, 1, '2026-06-15', 0.00, 3, false, true, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (143, NULL, 37, 7, '2026-06-13', 3.50, 3, true, true, 3.50, '2026-06-17', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (152, NULL, 37, 64, '2026-06-17', 3.50, 3, true, false, 3.49, '2026-06-17', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (153, NULL, 37, 24, '2026-06-19', 3.00, 3, false, true, 3.00, '2026-06-19', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (154, NULL, 37, 33, '2026-06-19', 3.50, 3, true, false, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (155, NULL, 37, 2, '2026-06-17', 3.00, 3, true, false, 2.50, '2026-06-17', 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (156, NULL, 37, 1, '2026-06-17', 0.00, 3, false, true, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (157, NULL, 39, 5, '2026-06-20', 3.50, 3, true, false, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (158, NULL, 39, 6, '2026-06-20', 3.50, 3, true, false, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (159, NULL, 39, 7, '2026-06-20', 3.50, 3, true, false, NULL, NULL, 1);
INSERT INTO public.lunch_assignments (id, enrollment_id, person_id, lunch_id, assigned_date, unit_price, assigned_by_id, has_debt, is_settled, debt_paid_amount, debt_paid_date, shift_id) VALUES (160, NULL, 39, 8, '2026-06-20', 3.50, 3, true, false, NULL, NULL, 1);


--
-- Data for Name: lunch_categories; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.lunch_categories (id, name) VALUES (2, 'Panes');
INSERT INTO public.lunch_categories (id, name) VALUES (3, 'Bebidas');
INSERT INTO public.lunch_categories (id, name) VALUES (4, 'Plato Frio');
INSERT INTO public.lunch_categories (id, name) VALUES (5, 'Postres');
INSERT INTO public.lunch_categories (id, name) VALUES (6, 'Kiosko');
INSERT INTO public.lunch_categories (id, name) VALUES (7, 'Fruta');
INSERT INTO public.lunch_categories (id, name) VALUES (8, 'Enrrollado de pollo');
INSERT INTO public.lunch_categories (id, name) VALUES (9, 'Enrrollado de atun');
INSERT INTO public.lunch_categories (id, name) VALUES (10, '0COPA');
INSERT INTO public.lunch_categories (id, name) VALUES (11, 'Pollo a la plancha');
INSERT INTO public.lunch_categories (id, name) VALUES (12, 'milanesa');


--
-- Data for Name: lunches; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (1, 2, 'gelatina', 0.00, 0.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (2, 2, 'picarones', 3.00, 3.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (3, 2, 'pan con huevo', 2.50, 2.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (4, 2, 'tortilla de brocoli', 3.50, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (5, 2, 'queque de chocolate', 3.50, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (6, 2, 'huevitos ala rusa', 3.50, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (7, 2, 'pan con atún', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (8, 2, 'torrejas de atun', 3.50, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (9, 2, 'pollo a la olla', 3.50, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (10, 2, 'Arros a al jardinera', 3.50, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (11, 2, 'Arroz jardinera', 3.50, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (12, 2, 'Huevos con papa', 3.50, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (13, 2, 'tallarines verdes', 3.50, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (14, 2, 'tallarin verdes', 3.50, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (15, 2, 'tallarin rojo', 3.50, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (17, 2, 'cancha salada', NULL, 3.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (18, 2, 'cancha dulce', NULL, 3.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (19, 2, 'Pollo a la plancha', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (20, 2, 'Pan tortilla de hot dog', NULL, 3.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (21, 2, 'Ensalada rusa', NULL, 3.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (22, 2, 'Papa rellena', NULL, 3.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (23, 2, 'salchicha', NULL, 3.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (24, 2, 'Pan con salchicha', NULL, 3.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (25, 2, 'Enrrollado de atun', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (26, 2, 'Enrrollado de pollo', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (27, 2, 'aji de gallina', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (28, 2, 'Pan con pollo', NULL, 2.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (29, 2, 'pollada', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (30, 2, 'Estofado de pollo', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (31, 2, 'tallarin sin crema', NULL, 3.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (32, 2, 'pan con pollo sin mayonesa', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (33, 2, 'tallarin con crema', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (34, 2, 'papa a la huancaina', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (35, 2, 'tallarin con pollo', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (36, 2, 'Pan con mortadela', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (37, 2, 'pan con tortilla', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (38, 2, 'Pan con pollo', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (39, 2, 'Hamburguesa', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (40, 2, 'Pan con Hotdog', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (41, 2, 'Pan con huevo', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (42, 3, 'jugo tropical', NULL, 1.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (43, 3, 'Infusión', NULL, 1.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (44, 3, 'yogurth solo', NULL, 1.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (45, 3, 'Chicha Morada', 0.00, 0.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (46, 4, 'Huevitos con papá', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (47, 4, 'tamal', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (48, 4, 'anticuchos', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (49, 4, 'Pollo al horno', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (51, 4, 'mazamorra', NULL, 1.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (52, 4, 'Brochetas', NULL, 3.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (53, 4, 'Combinado', NULL, 3.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (54, 4, 'Broster', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (55, 4, 'estafado con papa frita', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (56, 4, 'jugo de manzana', NULL, 1.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (57, 4, 'Lomito con arroz', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (58, 4, 'milanesa', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (59, 4, 'cereal', NULL, 0.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (60, 4, 'tallarin c/ crema s/ papa', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (61, 4, 'tequeños', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (62, 4, 'Panchitos a la parilla', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (63, 4, 'Salpicón', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (64, 4, 'Arroz con pollo', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (65, 4, 'Arroz chaufa', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (66, 4, 'Pastel de atún', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (67, 4, 'Papa a la Huancaina', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (68, 4, 'Salchipapa', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (69, 4, 'huevitos de codorniz', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (70, 4, 'Salchipollo', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (71, 5, 'Queque de vainilla', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (72, 5, 'cancha perla', NULL, 1.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (73, 5, 'torta de chocolate', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (74, 5, 'tamales', 3.00, 3.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (75, 5, 'ensalada de fruta', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (76, 5, 'Pudín', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (77, 5, 'Yogurt con cereal', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (78, 7, 'mandarina', NULL, 0.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (79, 7, 'manzana', NULL, 0.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (80, 7, 'platano', NULL, 0.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (81, 10, 'Ocopa', NULL, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (82, 12, 'milanesa', 3.50, 3.50, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (16, 2, 'TRorta de vainilla', 3.50, 0.00, NULL);
INSERT INTO public.lunches (id, lunch_category_id, lunch_name, cost_price, sale_price, comment) VALUES (50, 4, 'yuquitas a la huancaina', NULL, 0.00, NULL);


--
-- Data for Name: payment_debt_allocations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.payment_debt_allocations (id, payment_id, debt_id, amount_applied, allocated_at, notes) OVERRIDING SYSTEM VALUE VALUES (39, 31, 74, 330.75, '2026-06-22 15:35:15.260729-03', NULL);
INSERT INTO public.payment_debt_allocations (id, payment_id, debt_id, amount_applied, allocated_at, notes) OVERRIDING SYSTEM VALUE VALUES (40, 31, 101, 330.75, '2026-06-22 15:35:15.275115-03', NULL);
INSERT INTO public.payment_debt_allocations (id, payment_id, debt_id, amount_applied, allocated_at, notes) OVERRIDING SYSTEM VALUE VALUES (41, 31, 103, 138.50, '2026-06-22 15:35:15.275535-03', NULL);
INSERT INTO public.payment_debt_allocations (id, payment_id, debt_id, amount_applied, allocated_at, notes) OVERRIDING SYSTEM VALUE VALUES (42, 32, 103, 192.25, '2026-06-22 15:35:32.322665-03', NULL);
INSERT INTO public.payment_debt_allocations (id, payment_id, debt_id, amount_applied, allocated_at, notes) OVERRIDING SYSTEM VALUE VALUES (43, 32, 84, 330.75, '2026-06-22 15:35:32.322801-03', NULL);
INSERT INTO public.payment_debt_allocations (id, payment_id, debt_id, amount_applied, allocated_at, notes) OVERRIDING SYSTEM VALUE VALUES (44, 32, 105, 277.00, '2026-06-22 15:35:32.322823-03', NULL);
INSERT INTO public.payment_debt_allocations (id, payment_id, debt_id, amount_applied, allocated_at, notes) OVERRIDING SYSTEM VALUE VALUES (45, 33, 105, 53.75, '2026-06-22 15:35:44.158998-03', NULL);


--
-- Data for Name: payment_methods; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.payment_methods (id, name) VALUES (1, 'Efectivo');
INSERT INTO public.payment_methods (id, name) VALUES (2, 'Tarjeta de Crédito');
INSERT INTO public.payment_methods (id, name) VALUES (3, 'Tarjeta de Débito');
INSERT INTO public.payment_methods (id, name) VALUES (4, 'Transferencia Bancaria');
INSERT INTO public.payment_methods (id, name) VALUES (5, 'Yape');
INSERT INTO public.payment_methods (id, name) VALUES (6, 'Plin');


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (19, '2026-05-26', 300.00, 4, NULL, NULL, NULL, false, NULL, NULL, '2026-05-26 16:06:24.284061-03');
INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (20, '2026-05-26', 500.00, 5, NULL, NULL, NULL, false, NULL, NULL, '2026-05-26 16:07:00.499306-03');
INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (21, '2026-05-26', 330.75, 3, NULL, NULL, NULL, false, NULL, NULL, '2026-05-26 16:09:47.667477-03');
INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (22, '2026-05-26', 600.00, 6, NULL, NULL, NULL, false, NULL, NULL, '2026-05-26 16:10:54.264378-03');
INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (23, '2026-06-02', 550.00, 3, NULL, NULL, NULL, false, NULL, NULL, '2026-06-02 11:26:15.183314-03');
INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (24, '2026-06-05', 550.00, 4, NULL, NULL, NULL, false, NULL, NULL, '2026-06-05 18:31:16.246528-03');
INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (25, '2026-06-15', 600.00, 1, NULL, NULL, NULL, false, NULL, NULL, '2026-06-15 15:40:59.268965-03');
INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (26, '2026-06-15', 70.00, 2, NULL, NULL, NULL, false, NULL, NULL, '2026-06-15 15:41:25.077098-03');
INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (27, '2026-06-17', 600.00, 5, NULL, NULL, NULL, false, NULL, NULL, '2026-06-17 14:08:43.361304-03');
INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (28, '2026-06-17', 450.00, 5, NULL, NULL, NULL, false, NULL, NULL, '2026-06-17 14:22:52.016725-03');
INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (29, '2026-06-17', 500.00, 5, NULL, NULL, NULL, false, NULL, NULL, '2026-06-17 14:44:56.811922-03');
INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (30, '2026-06-17', 600.00, 3, NULL, NULL, NULL, false, NULL, NULL, '2026-06-17 15:02:09.391817-03');
INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (31, '2026-06-22', 800.00, 5, NULL, NULL, NULL, false, NULL, NULL, '2026-06-22 15:35:15.141011-03');
INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (32, '2026-06-22', 800.00, 2, NULL, NULL, NULL, false, NULL, NULL, '2026-06-22 15:35:32.320276-03');
INSERT INTO public.payments (id, payment_date, amount, payment_method_id, n_operation, created_by, notes, is_voided, voided_at, voided_by, created_at) VALUES (33, '2026-06-22', 53.75, 4, NULL, NULL, NULL, false, NULL, NULL, '2026-06-22 15:35:44.156522-03');


--
-- Data for Name: permissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.permissions (id, name) VALUES (9, 'student.create');
INSERT INTO public.permissions (id, name) VALUES (10, 'student.read');
INSERT INTO public.permissions (id, name) VALUES (11, 'student.update');
INSERT INTO public.permissions (id, name) VALUES (12, 'student.delete');
INSERT INTO public.permissions (id, name) VALUES (13, 'student.change_document');
INSERT INTO public.permissions (id, name) VALUES (14, 'institution.create');
INSERT INTO public.permissions (id, name) VALUES (15, 'institution.read');
INSERT INTO public.permissions (id, name) VALUES (16, 'institution.update');
INSERT INTO public.permissions (id, name) VALUES (17, 'institution.delete');
INSERT INTO public.permissions (id, name) VALUES (18, 'school-year.create');
INSERT INTO public.permissions (id, name) VALUES (19, 'school-year.read');
INSERT INTO public.permissions (id, name) VALUES (20, 'school-year.update');
INSERT INTO public.permissions (id, name) VALUES (21, 'school-year.delete');
INSERT INTO public.permissions (id, name) VALUES (22, 'grade.create');
INSERT INTO public.permissions (id, name) VALUES (23, 'grade.read');
INSERT INTO public.permissions (id, name) VALUES (24, 'grade.update');
INSERT INTO public.permissions (id, name) VALUES (25, 'grade.delete');
INSERT INTO public.permissions (id, name) VALUES (26, 'level.create');
INSERT INTO public.permissions (id, name) VALUES (27, 'level.read');
INSERT INTO public.permissions (id, name) VALUES (28, 'level.update');
INSERT INTO public.permissions (id, name) VALUES (29, 'level.delete');
INSERT INTO public.permissions (id, name) VALUES (30, 'grade-offering.create');
INSERT INTO public.permissions (id, name) VALUES (31, 'grade-offering.read');
INSERT INTO public.permissions (id, name) VALUES (32, 'grade-offering.update');
INSERT INTO public.permissions (id, name) VALUES (33, 'grade-offering.delete');
INSERT INTO public.permissions (id, name) VALUES (34, 'shift.create');
INSERT INTO public.permissions (id, name) VALUES (35, 'shift.read');
INSERT INTO public.permissions (id, name) VALUES (36, 'shift.update');
INSERT INTO public.permissions (id, name) VALUES (37, 'shift.delete');
INSERT INTO public.permissions (id, name) VALUES (38, 'enrollment.read');
INSERT INTO public.permissions (id, name) VALUES (39, 'enrollment.create');
INSERT INTO public.permissions (id, name) VALUES (40, 'school-fee-concept.read');
INSERT INTO public.permissions (id, name) VALUES (41, 'school-fee-concept.create');
INSERT INTO public.permissions (id, name) VALUES (42, 'school-fee-concept.update');
INSERT INTO public.permissions (id, name) VALUES (43, 'school-fee-concept.delete');
INSERT INTO public.permissions (id, name) VALUES (44, 'section.read');
INSERT INTO public.permissions (id, name) VALUES (45, 'enrollment.update');
INSERT INTO public.permissions (id, name) VALUES (46, 'enrollment.delete');
INSERT INTO public.permissions (id, name) VALUES (47, 'enrollment-debt.read');
INSERT INTO public.permissions (id, name) VALUES (48, 'debt-installment.read');
INSERT INTO public.permissions (id, name) VALUES (49, 'payment-method.read');
INSERT INTO public.permissions (id, name) VALUES (50, 'payment.create');
INSERT INTO public.permissions (id, name) VALUES (51, 'accounting-plan.create');
INSERT INTO public.permissions (id, name) VALUES (52, 'accounting-plan.read');
INSERT INTO public.permissions (id, name) VALUES (53, 'accounting-plan.update');
INSERT INTO public.permissions (id, name) VALUES (54, 'accounting-plan.delete');
INSERT INTO public.permissions (id, name) VALUES (55, 'work-area.read');
INSERT INTO public.permissions (id, name) VALUES (56, 'work-area.create');
INSERT INTO public.permissions (id, name) VALUES (57, 'work-area.update');
INSERT INTO public.permissions (id, name) VALUES (58, 'work-area.delete');
INSERT INTO public.permissions (id, name) VALUES (59, 'job-position.read');
INSERT INTO public.permissions (id, name) VALUES (60, 'job-position.create');
INSERT INTO public.permissions (id, name) VALUES (61, 'job-position.update');
INSERT INTO public.permissions (id, name) VALUES (62, 'job-position.delete');
INSERT INTO public.permissions (id, name) VALUES (63, 'staff-member.create');
INSERT INTO public.permissions (id, name) VALUES (64, 'staff-member.read');
INSERT INTO public.permissions (id, name) VALUES (65, 'staff-member.update');
INSERT INTO public.permissions (id, name) VALUES (66, 'staff-member.delete');
INSERT INTO public.permissions (id, name) VALUES (67, 'employment-contract.create');
INSERT INTO public.permissions (id, name) VALUES (68, 'employment-contract.read');
INSERT INTO public.permissions (id, name) VALUES (69, 'employment-contract.update');
INSERT INTO public.permissions (id, name) VALUES (70, 'employment-contract.delete');
INSERT INTO public.permissions (id, name) VALUES (71, 'lunch-category.read');
INSERT INTO public.permissions (id, name) VALUES (72, 'lunch-category.create');
INSERT INTO public.permissions (id, name) VALUES (73, 'lunch-category.update');
INSERT INTO public.permissions (id, name) VALUES (74, 'lunch-category.delete');
INSERT INTO public.permissions (id, name) VALUES (75, 'lunch.read');
INSERT INTO public.permissions (id, name) VALUES (76, 'lunch.create');
INSERT INTO public.permissions (id, name) VALUES (77, 'lunch.update');
INSERT INTO public.permissions (id, name) VALUES (78, 'lunch.delete');
INSERT INTO public.permissions (id, name) VALUES (79, 'lunch-assignment.create');
INSERT INTO public.permissions (id, name) VALUES (80, 'lunch-assignment.read');
INSERT INTO public.permissions (id, name) VALUES (81, 'lunch-assignment.delete');
INSERT INTO public.permissions (id, name) VALUES (82, 'lunch-payment.create');


--
-- Data for Name: person; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.person (id, names, paternal_lastname, maternal_lastname, gender_id, birth_date, document_type_id, id_document_number, address, address_ubigeo_id, email, landline_phone, cell_phone, civil_state_id, religion_id, ethnic_self_identification_id, native_language_id) VALUES (39, 'Nombre39', 'Apellido39', 'Materno39', 1, '2006-06-17', 1, '00000039', 'Direccion de prueba 39', 691, NULL, NULL, '900000039', 4, 3, 2, 14);
INSERT INTO public.person (id, names, paternal_lastname, maternal_lastname, gender_id, birth_date, document_type_id, id_document_number, address, address_ubigeo_id, email, landline_phone, cell_phone, civil_state_id, religion_id, ethnic_self_identification_id, native_language_id) VALUES (41, 'Nombre41', 'Apellido41', 'Materno41', 1, '2008-03-06', 1, '00000041', 'Direccion de prueba 41', 1160, NULL, NULL, '900000041', 1, 1, NULL, 12);
INSERT INTO public.person (id, names, paternal_lastname, maternal_lastname, gender_id, birth_date, document_type_id, id_document_number, address, address_ubigeo_id, email, landline_phone, cell_phone, civil_state_id, religion_id, ethnic_self_identification_id, native_language_id) VALUES (42, 'Nombre42', 'Apellido42', 'Materno42', 2, '1900-10-06', 1, '00000042', 'Direccion de prueba 42', 1160, NULL, '000000042', NULL, 2, 4, NULL, 15);
INSERT INTO public.person (id, names, paternal_lastname, maternal_lastname, gender_id, birth_date, document_type_id, id_document_number, address, address_ubigeo_id, email, landline_phone, cell_phone, civil_state_id, religion_id, ethnic_self_identification_id, native_language_id) VALUES (38, 'Nombre38', 'Apellido38', 'Materno38', 2, '1971-05-04', 1, '00000038', 'Direccion de prueba 38', 1565, NULL, NULL, NULL, 2, 5, 1, 14);
INSERT INTO public.person (id, names, paternal_lastname, maternal_lastname, gender_id, birth_date, document_type_id, id_document_number, address, address_ubigeo_id, email, landline_phone, cell_phone, civil_state_id, religion_id, ethnic_self_identification_id, native_language_id) VALUES (40, 'Nombre40', 'Apellido40', 'Materno40', 1, '1231-05-05', 1, '00000040', 'Direccion de prueba 40', 1160, NULL, NULL, NULL, 4, 4, NULL, 15);
INSERT INTO public.person (id, names, paternal_lastname, maternal_lastname, gender_id, birth_date, document_type_id, id_document_number, address, address_ubigeo_id, email, landline_phone, cell_phone, civil_state_id, religion_id, ethnic_self_identification_id, native_language_id) VALUES (37, 'Nombre37', 'Apellido37', 'Materno37', 2, '2006-04-06', 1, '00000037', 'Direccion de prueba 37', 1160, 'persona37@example.test', NULL, '900000037', 1, 2, 3, 13);
INSERT INTO public.person (id, names, paternal_lastname, maternal_lastname, gender_id, birth_date, document_type_id, id_document_number, address, address_ubigeo_id, email, landline_phone, cell_phone, civil_state_id, religion_id, ethnic_self_identification_id, native_language_id) VALUES (43, 'Nombre43', 'Apellido43', 'Materno43', 1, '1971-07-01', 1, '00000043', 'Direccion de prueba 43', 809, NULL, NULL, '900000043', 2, 3, NULL, NULL);
INSERT INTO public.person (id, names, paternal_lastname, maternal_lastname, gender_id, birth_date, document_type_id, id_document_number, address, address_ubigeo_id, email, landline_phone, cell_phone, civil_state_id, religion_id, ethnic_self_identification_id, native_language_id) VALUES (44, 'Nombre44', 'Apellido44', 'Materno44', 1, '2012-06-20', 1, '00000044', 'Direccion de prueba 44', 993, NULL, NULL, NULL, 1, 1, 4, 10);
INSERT INTO public.person (id, names, paternal_lastname, maternal_lastname, gender_id, birth_date, document_type_id, id_document_number, address, address_ubigeo_id, email, landline_phone, cell_phone, civil_state_id, religion_id, ethnic_self_identification_id, native_language_id) VALUES (45, 'Nombre45', 'Apellido45', 'Materno45', 2, '1976-10-31', 1, '00000045', 'Direccion de prueba 45', 1092, NULL, '000000045', NULL, 2, 3, 1, 14);
INSERT INTO public.person (id, names, paternal_lastname, maternal_lastname, gender_id, birth_date, document_type_id, id_document_number, address, address_ubigeo_id, email, landline_phone, cell_phone, civil_state_id, religion_id, ethnic_self_identification_id, native_language_id) VALUES (46, 'Nombre46', 'Apellido46', 'Materno46', 1, '2004-10-31', 1, '00000046', 'Direccion de prueba 46', 1160, NULL, NULL, '900000046', 1, 4, NULL, 1);
INSERT INTO public.person (id, names, paternal_lastname, maternal_lastname, gender_id, birth_date, document_type_id, id_document_number, address, address_ubigeo_id, email, landline_phone, cell_phone, civil_state_id, religion_id, ethnic_self_identification_id, native_language_id) VALUES (47, 'Nombre47', 'Apellido47', 'Materno47', 2, '1966-06-06', 1, '00000047', 'Direccion de prueba 47', 909, 'persona47@example.test', '000000047', NULL, 2, 2, NULL, 12);
INSERT INTO public.person (id, names, paternal_lastname, maternal_lastname, gender_id, birth_date, document_type_id, id_document_number, address, address_ubigeo_id, email, landline_phone, cell_phone, civil_state_id, religion_id, ethnic_self_identification_id, native_language_id) VALUES (48, 'Nombre48', 'Apellido48', 'Materno48', 1, '1990-07-19', 1, '00000048', 'Direccion de prueba 48', 809, NULL, NULL, '900000048', 2, NULL, NULL, NULL);


--
-- Data for Name: province; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.province (id, name, department_id, code) VALUES (1, 'CHACHAPOYAS', 1, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (22, 'BAGUA', 1, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (28, 'BONGARA', 1, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (40, 'CONDORCANQUI', 1, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (43, 'LUYA', 1, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (66, 'RODRIGUEZ DE MENDOZA', 1, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (78, 'UTCUBAMBA', 1, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (85, 'HUARAZ', 85, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (97, 'AIJA', 85, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (102, 'ANTONIO RAYMONDI', 85, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (108, 'ASUNCION', 85, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (110, 'BOLOGNESI', 85, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (125, 'CARHUAZ', 85, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (136, 'CARLOS FERMIN FITZCARRALD', 85, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (139, 'CASMA', 85, '08');
INSERT INTO public.province (id, name, department_id, code) VALUES (143, 'CORONGO', 85, '09');
INSERT INTO public.province (id, name, department_id, code) VALUES (150, 'HUARI', 85, '10');
INSERT INTO public.province (id, name, department_id, code) VALUES (166, 'HUARMEY', 85, '11');
INSERT INTO public.province (id, name, department_id, code) VALUES (171, 'HUAYLAS', 85, '12');
INSERT INTO public.province (id, name, department_id, code) VALUES (181, 'MARISCAL LUZURIAGA', 85, '13');
INSERT INTO public.province (id, name, department_id, code) VALUES (189, 'OCROS', 85, '14');
INSERT INTO public.province (id, name, department_id, code) VALUES (199, 'PALLASCA', 85, '15');
INSERT INTO public.province (id, name, department_id, code) VALUES (210, 'POMABAMBA', 85, '16');
INSERT INTO public.province (id, name, department_id, code) VALUES (214, 'RECUAY', 85, '17');
INSERT INTO public.province (id, name, department_id, code) VALUES (224, 'SANTA', 85, '18');
INSERT INTO public.province (id, name, department_id, code) VALUES (233, 'SIHUAS', 85, '19');
INSERT INTO public.province (id, name, department_id, code) VALUES (243, 'YUNGAY', 85, '20');
INSERT INTO public.province (id, name, department_id, code) VALUES (251, 'ABANCAY', 251, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (260, 'ANDAHUAYLAS', 251, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (280, 'ANTABAMBA', 251, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (287, 'AYMARAES', 251, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (304, 'COTABAMBAS', 251, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (310, 'CHINCHEROS', 251, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (321, 'GRAU', 251, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (335, 'AREQUIPA', 335, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (364, 'CAMANA', 335, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (372, 'CARAVELI', 335, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (385, 'CASTILLA', 335, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (399, 'CAYLLOMA', 335, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (419, 'CONDESUYOS', 335, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (427, 'ISLAY', 335, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (433, 'LA UNION', 335, '08');
INSERT INTO public.province (id, name, department_id, code) VALUES (444, 'HUAMANGA', 444, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (460, 'CANGALLO', 444, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (466, 'HUANCA SANCOS', 444, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (470, 'HUANTA', 444, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (482, 'LA MAR', 444, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (493, 'LUCANAS', 444, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (514, 'PARINACOCHAS', 444, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (522, 'PAUCAR DEL SARA SARA', 444, '08');
INSERT INTO public.province (id, name, department_id, code) VALUES (532, 'SUCRE', 444, '09');
INSERT INTO public.province (id, name, department_id, code) VALUES (543, 'VICTOR FAJARDO', 444, '10');
INSERT INTO public.province (id, name, department_id, code) VALUES (555, 'VILCAS HUAMAN', 444, '11');
INSERT INTO public.province (id, name, department_id, code) VALUES (563, 'CAJAMARCA', 563, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (575, 'CAJABAMBA', 563, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (579, 'CELENDIN', 563, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (591, 'CHOTA', 563, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (610, 'CONTUMAZA', 563, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (618, 'CUTERVO', 563, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (633, 'HUALGAYOC', 563, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (636, 'JAEN', 563, '08');
INSERT INTO public.province (id, name, department_id, code) VALUES (648, 'SAN IGNACIO', 563, '09');
INSERT INTO public.province (id, name, department_id, code) VALUES (655, 'SAN MARCOS', 563, '10');
INSERT INTO public.province (id, name, department_id, code) VALUES (662, 'SAN MIGUEL', 563, '11');
INSERT INTO public.province (id, name, department_id, code) VALUES (675, 'SAN PABLO', 563, '12');
INSERT INTO public.province (id, name, department_id, code) VALUES (679, 'SANTA CRUZ', 563, '13');
INSERT INTO public.province (id, name, department_id, code) VALUES (690, 'CALLAO', 690, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (697, 'CUSCO', 697, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (705, 'ACOMAYO', 697, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (712, 'ANTA', 697, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (721, 'CALCA', 697, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (729, 'CANAS', 697, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (737, 'CANCHIS', 697, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (745, 'CHUMBIVILCAS', 697, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (753, 'ESPINAR', 697, '08');
INSERT INTO public.province (id, name, department_id, code) VALUES (761, 'LA CONVENCION', 697, '09');
INSERT INTO public.province (id, name, department_id, code) VALUES (775, 'PARURO', 697, '10');
INSERT INTO public.province (id, name, department_id, code) VALUES (784, 'PAUCARTAMBO', 697, '11');
INSERT INTO public.province (id, name, department_id, code) VALUES (790, 'QUISPICANCHI', 697, '12');
INSERT INTO public.province (id, name, department_id, code) VALUES (802, 'URUBAMBA', 697, '13');
INSERT INTO public.province (id, name, department_id, code) VALUES (809, 'HUANCAVELICA', 809, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (828, 'ACOBAMBA', 809, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (836, 'ANGARAES', 809, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (848, 'CASTROVIRREYNA', 809, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (861, 'CHURCAMPA', 809, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (872, 'HUAYTARA', 809, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (888, 'TAYACAJA', 809, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (909, 'HUANUCO', 909, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (922, 'AMBO', 909, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (930, 'DOS DE MAYO', 909, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (939, 'HUACAYBAMBA', 909, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (943, 'HUAMALIES', 909, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (954, 'LEONCIO PRADO', 909, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (964, 'MARAÑON', 909, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (969, 'PACHITEA', 909, '08');
INSERT INTO public.province (id, name, department_id, code) VALUES (973, 'PUERTO INCA', 909, '09');
INSERT INTO public.province (id, name, department_id, code) VALUES (978, 'LAURICOCHA', 909, '10');
INSERT INTO public.province (id, name, department_id, code) VALUES (985, 'YAROWILCA', 909, '11');
INSERT INTO public.province (id, name, department_id, code) VALUES (993, 'ICA', 993, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1007, 'CHINCHA', 993, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1018, 'NASCA', 993, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1023, 'PALPA', 993, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (1028, 'PISCO', 993, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (1036, 'HUANCAYO', 1036, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1064, 'CONCEPCION', 1036, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1079, 'CHANCHAMAYO', 1036, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1085, 'JAUJA', 1036, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (1119, 'JUNIN', 1036, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (1123, 'SATIPO', 1036, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (1132, 'TARMA', 1036, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (1141, 'YAULI', 1036, '08');
INSERT INTO public.province (id, name, department_id, code) VALUES (1151, 'CHUPACA', 1036, '09');
INSERT INTO public.province (id, name, department_id, code) VALUES (1160, 'TRUJILLO', 1160, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1171, 'ASCOPE', 1160, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1179, 'BOLIVAR', 1160, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1185, 'CHEPEN', 1160, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (1188, 'JULCAN', 1160, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (1192, 'OTUZCO', 1160, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (1202, 'PACASMAYO', 1160, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (1207, 'PATAZ', 1160, '08');
INSERT INTO public.province (id, name, department_id, code) VALUES (1220, 'SANCHEZ CARRION', 1160, '09');
INSERT INTO public.province (id, name, department_id, code) VALUES (1228, 'SANTIAGO DE CHUCO', 1160, '10');
INSERT INTO public.province (id, name, department_id, code) VALUES (1236, 'GRAN CHIMU', 1160, '11');
INSERT INTO public.province (id, name, department_id, code) VALUES (1240, 'VIRU', 1160, '12');
INSERT INTO public.province (id, name, department_id, code) VALUES (1243, 'CHICLAYO', 1243, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1263, 'FERREÑAFE', 1243, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1269, 'LAMBAYEQUE', 1243, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1281, 'LIMA', 1281, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1324, 'BARRANCA', 1281, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1329, 'CAJATAMBO', 1281, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1334, 'CANTA', 1281, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (1341, 'CAÑETE', 1281, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (1357, 'HUARAL', 1281, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (1369, 'HUAROCHIRI', 1281, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (1401, 'HUAURA', 1281, '08');
INSERT INTO public.province (id, name, department_id, code) VALUES (1413, 'OYON', 1281, '09');
INSERT INTO public.province (id, name, department_id, code) VALUES (1419, 'YAUYOS', 1281, '10');
INSERT INTO public.province (id, name, department_id, code) VALUES (1452, 'MAYNAS', 1452, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1463, 'ALTO AMAZONAS', 1452, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1469, 'LORETO', 1452, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1474, 'MARISCAL RAMON CASTILLA', 1452, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (1478, 'REQUENA', 1452, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (1489, 'UCAYALI', 1452, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (1495, 'DATEM DEL MARAÑON', 1452, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (1501, 'PUTUMAYO', 1452, '08');
INSERT INTO public.province (id, name, department_id, code) VALUES (1505, 'TAMBOPATA', 1505, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1509, 'MANU', 1505, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1513, 'TAHUAMANU', 1505, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1516, 'MARISCAL NIETO', 1516, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1522, 'GENERAL SANCHEZ CERRO', 1516, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1533, 'ILO', 1516, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1536, 'PASCO', 1536, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1549, 'DANIEL ALCIDES CARRION', 1536, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1557, 'OXAPAMPA', 1536, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1565, 'PIURA', 1565, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1575, 'AYABACA', 1565, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1585, 'HUANCABAMBA', 1565, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1593, 'MORROPON', 1565, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (1603, 'PAITA', 1565, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (1610, 'SULLANA', 1565, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (1618, 'TALARA', 1565, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (1624, 'SECHURA', 1565, '08');
INSERT INTO public.province (id, name, department_id, code) VALUES (1630, 'PUNO', 1630, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1645, 'AZANGARO', 1630, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1660, 'CARABAYA', 1630, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1670, 'CHUCUITO', 1630, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (1677, 'EL COLLAO', 1630, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (1682, 'HUANCANE', 1630, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (1690, 'LAMPA', 1630, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (1700, 'MELGAR', 1630, '08');
INSERT INTO public.province (id, name, department_id, code) VALUES (1709, 'MOHO', 1630, '09');
INSERT INTO public.province (id, name, department_id, code) VALUES (1713, 'SAN ANTONIO DE PUTINA', 1630, '10');
INSERT INTO public.province (id, name, department_id, code) VALUES (1718, 'SAN ROMAN', 1630, '11');
INSERT INTO public.province (id, name, department_id, code) VALUES (1723, 'SANDIA', 1630, '12');
INSERT INTO public.province (id, name, department_id, code) VALUES (1733, 'YUNGUYO', 1630, '13');
INSERT INTO public.province (id, name, department_id, code) VALUES (1740, 'MOYOBAMBA', 1740, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1746, 'BELLAVISTA', 1740, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1752, 'EL DORADO', 1740, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1757, 'HUALLAGA', 1740, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (1763, 'LAMAS', 1740, '05');
INSERT INTO public.province (id, name, department_id, code) VALUES (1774, 'MARISCAL CACERES', 1740, '06');
INSERT INTO public.province (id, name, department_id, code) VALUES (1779, 'PICOTA', 1740, '07');
INSERT INTO public.province (id, name, department_id, code) VALUES (1789, 'RIOJA', 1740, '08');
INSERT INTO public.province (id, name, department_id, code) VALUES (1798, 'SAN MARTIN', 1740, '09');
INSERT INTO public.province (id, name, department_id, code) VALUES (1812, 'TOCACHE', 1740, '10');
INSERT INTO public.province (id, name, department_id, code) VALUES (1817, 'TACNA', 1817, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1828, 'CANDARAVE', 1817, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1834, 'JORGE BASADRE', 1817, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1837, 'TARATA', 1817, '04');
INSERT INTO public.province (id, name, department_id, code) VALUES (1845, 'TUMBES', 1845, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1851, 'CONTRALMIRANTE VILLAR', 1845, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1854, 'ZARUMILLA', 1845, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1858, 'CORONEL PORTILLO', 1858, '01');
INSERT INTO public.province (id, name, department_id, code) VALUES (1865, 'ATALAYA', 1858, '02');
INSERT INTO public.province (id, name, department_id, code) VALUES (1869, 'PADRE ABAD', 1858, '03');
INSERT INTO public.province (id, name, department_id, code) VALUES (1874, 'PURUS', 1858, '04');


--
-- Data for Name: religion; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.religion (id, name) VALUES (1, 'Católica');
INSERT INTO public.religion (id, name) VALUES (2, 'Evangélica / Cristiana');
INSERT INTO public.religion (id, name) VALUES (3, 'Adventista');
INSERT INTO public.religion (id, name) VALUES (4, 'Testigo de Jehová');
INSERT INTO public.religion (id, name) VALUES (5, 'Mormona');
INSERT INTO public.religion (id, name) VALUES (6, 'Judía');
INSERT INTO public.religion (id, name) VALUES (7, 'Islámica');
INSERT INTO public.religion (id, name) VALUES (8, 'Budista');
INSERT INTO public.religion (id, name) VALUES (9, 'Otra');
INSERT INTO public.religion (id, name) VALUES (10, 'Ninguna');


--
-- Data for Name: role_permissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 10);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 11);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 13);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 9);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 12);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 14);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 15);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 16);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 17);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 18);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 19);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 20);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 21);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 22);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 23);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 24);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 25);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 26);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 27);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 28);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 29);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 30);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 31);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 32);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 33);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 34);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 35);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 36);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 37);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 38);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 39);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 40);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 41);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 42);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 43);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 44);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 45);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 46);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 47);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 48);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 49);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 50);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 51);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 52);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 53);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 54);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 55);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 56);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 57);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 58);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 59);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 60);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 61);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 62);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 63);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 64);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 65);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 66);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 67);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 68);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 69);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 70);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 71);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 72);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 73);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 74);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 75);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 76);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 77);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 78);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 79);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 80);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 81);
INSERT INTO public.role_permissions (role_id, permission_id) VALUES (7, 82);


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.roles (id, name) VALUES (8, 'editor');
INSERT INTO public.roles (id, name) VALUES (9, 'viewer');
INSERT INTO public.roles (id, name) VALUES (7, 'superadmin');


--
-- Data for Name: ruc_states; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.ruc_states (id, name) VALUES (1, 'Activo');
INSERT INTO public.ruc_states (id, name) VALUES (2, 'Suspensión temporal');
INSERT INTO public.ruc_states (id, name) VALUES (3, 'Baja provisional');
INSERT INTO public.ruc_states (id, name) VALUES (4, 'Baja definitiva');
INSERT INTO public.ruc_states (id, name) VALUES (5, 'Baja provisional de oficion');
INSERT INTO public.ruc_states (id, name) VALUES (6, 'Baja definitiva de oficio');


--
-- Data for Name: school_fee; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (232, 11, 1, 1, 3, 200.00, 110.00, 100.00, 'Original: HERMANO 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (135, 4, 1, 1, 1, 110.00, 120.00, 140.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (136, 4, 2, 1, 1, 120.00, 130.00, 130.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (137, 4, 3, 1, 1, 130.00, 130.00, 120.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (138, 5, 1, 1, 1, 300.00, 130.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (139, 5, 2, 1, 1, 300.00, 140.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (140, 5, 3, 1, 1, 300.00, 140.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (141, 5, 1, 2, 1, 250.00, 110.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (142, 5, 2, 2, 1, 250.00, 130.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (143, 5, 1, 1, 3, 200.00, 110.00, 0.00, 'Original: Hermano');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (144, 5, 2, 1, 3, 200.00, 120.00, 0.00, 'Original: Hermano');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (145, 5, 3, 1, 3, 200.00, 120.00, 0.00, 'Original: Hermano');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (146, 5, 1, 2, 3, 200.00, 100.00, 0.00, 'Original: Hermano');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (147, 5, 2, 2, 3, 200.00, 110.00, 0.00, 'Original: Hermano');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (148, 5, 1, 1, 4, 0.00, 110.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (149, 5, 2, 1, 4, 0.00, 110.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (150, 5, 3, 1, 4, 0.00, 110.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (151, 6, 1, 1, 1, 300.00, 140.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (152, 6, 1, 2, 1, 250.00, 130.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (153, 6, 2, 1, 1, 300.00, 140.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (154, 6, 2, 2, 1, 250.00, 130.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (155, 6, 3, 1, 1, 300.00, 150.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (156, 6, 1, 1, 3, 200.00, 120.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (157, 6, 1, 2, 3, 200.00, 110.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (158, 6, 2, 1, 3, 200.00, 120.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (159, 6, 2, 2, 3, 200.00, 110.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (160, 6, 3, 1, 3, 200.00, 130.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (161, 6, 1, 1, 4, 100.00, 100.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (162, 6, 2, 1, 4, 100.00, 100.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (163, 6, 3, 1, 4, 100.00, 110.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (164, 7, 1, 1, 1, 300.00, 150.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (165, 7, 1, 2, 1, 300.00, 140.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (166, 7, 2, 1, 1, 300.00, 150.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (167, 7, 2, 2, 1, 300.00, 140.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (168, 7, 3, 1, 1, 300.00, 160.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (169, 7, 3, 2, 1, 300.00, 160.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (170, 7, 1, 1, 3, 200.00, 130.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (171, 7, 1, 2, 3, 200.00, 120.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (172, 7, 2, 1, 3, 200.00, 130.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (173, 7, 2, 2, 3, 200.00, 120.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (174, 7, 3, 1, 3, 200.00, 140.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (175, 7, 3, 2, 3, 200.00, 140.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (176, 7, 1, 1, 4, 100.00, 120.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (177, 7, 1, 2, 4, 100.00, 110.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (178, 7, 2, 1, 4, 100.00, 120.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (179, 7, 2, 2, 4, 100.00, 110.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (180, 7, 3, 1, 4, 100.00, 120.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (181, 7, 3, 2, 4, 100.00, 120.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (182, 8, 1, 1, 1, 300.00, 166.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (183, 8, 1, 2, 1, 300.00, 156.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (184, 8, 2, 1, 1, 300.00, 166.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (185, 8, 2, 2, 1, 300.00, 156.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (186, 8, 3, 1, 1, 300.00, 176.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (187, 8, 1, 1, 3, 200.00, 140.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (188, 8, 1, 2, 3, 200.00, 130.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (189, 8, 2, 1, 3, 200.00, 140.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (190, 8, 2, 2, 3, 200.00, 130.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (191, 8, 3, 1, 3, 200.00, 150.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (192, 8, 1, 1, 4, 100.00, 130.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (193, 8, 1, 2, 4, 100.00, 120.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (194, 8, 2, 1, 4, 100.00, 130.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (195, 8, 2, 2, 4, 100.00, 120.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (196, 8, 3, 1, 4, 100.00, 140.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (197, 9, 1, 1, 1, 192.00, 192.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (198, 9, 1, 2, 1, 182.00, 182.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (199, 9, 2, 1, 1, 192.00, 192.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (200, 9, 2, 2, 1, 182.00, 182.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (201, 9, 3, 1, 1, 210.00, 210.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (202, 9, 1, 1, 3, 170.00, 170.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (203, 9, 1, 2, 3, 160.00, 160.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (204, 9, 2, 1, 3, 170.00, 170.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (205, 9, 2, 2, 3, 160.00, 160.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (206, 9, 3, 1, 3, 190.00, 190.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (207, 9, 1, 1, 4, 150.00, 150.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (208, 9, 1, 2, 4, 140.00, 140.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (209, 9, 2, 1, 4, 150.00, 150.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (210, 9, 2, 2, 4, 140.00, 140.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (211, 9, 3, 1, 4, 170.00, 170.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (212, 10, 1, 1, 1, 212.00, 212.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (213, 10, 1, 2, 1, 202.00, 202.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (214, 10, 2, 1, 1, 212.00, 212.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (215, 10, 2, 2, 1, 202.00, 202.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (216, 10, 3, 1, 1, 230.00, 230.00, 0.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (217, 10, 1, 1, 3, 190.00, 190.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (218, 10, 1, 2, 3, 180.00, 180.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (219, 10, 2, 1, 3, 190.00, 190.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (220, 10, 2, 2, 3, 180.00, 180.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (221, 10, 3, 1, 3, 210.00, 210.00, 0.00, 'Original: Hermano 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (222, 10, 1, 1, 4, 170.00, 170.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (223, 10, 1, 2, 4, 160.00, 160.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (224, 10, 2, 1, 4, 170.00, 170.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (225, 10, 2, 2, 4, 160.00, 160.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (226, 10, 3, 1, 4, 190.00, 190.00, 0.00, 'Original: Hermano 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (227, 11, 1, 1, 1, 235.00, 110.00, 100.00, 'Original: NORMAL');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (228, 11, 1, 2, 1, 225.00, 110.00, 100.00, 'Original: NORMAL');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (229, 11, 2, 1, 1, 235.00, 120.00, 100.00, 'Original: NORMAL');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (230, 11, 2, 2, 1, 225.00, 120.00, 100.00, 'Original: NORMAL');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (231, 11, 3, 1, 1, 250.00, 140.00, 100.00, 'Original: NORMAL');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (233, 11, 1, 2, 3, 190.00, 110.00, 100.00, 'Original: HERMANO 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (234, 11, 2, 1, 3, 200.00, 120.00, 100.00, 'Original: HERMANO 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (235, 11, 2, 2, 3, 190.00, 120.00, 100.00, 'Original: HERMANO 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (236, 11, 3, 1, 3, 220.00, 140.00, 100.00, 'Original: HERMANO 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (237, 11, 1, 1, 4, 190.00, 110.00, 50.00, 'Original: HERMANO 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (238, 11, 1, 2, 4, 180.00, 110.00, 50.00, 'Original: HERMANO 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (239, 11, 2, 1, 4, 190.00, 120.00, 50.00, 'Original: HERMANO 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (240, 11, 2, 2, 4, 180.00, 120.00, 50.00, 'Original: HERMANO 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (241, 11, 3, 1, 4, 210.00, 140.00, 50.00, 'Original: HERMANO 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (242, 12, 1, 1, 1, 130.00, 130.00, 100.00, 'Original: VIRTUAL');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (243, 12, 1, 2, 1, 130.00, 130.00, 100.00, 'Original: VIRTUAL');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (244, 12, 2, 1, 1, 170.00, 170.00, 100.00, 'Original: VIRTUAL');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (245, 12, 2, 2, 1, 170.00, 170.00, 100.00, 'Original: VIRTUAL');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (246, 12, 3, 1, 1, 180.00, 180.00, 100.00, 'Original: VIRTUAL');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (247, 13, 1, 1, 1, 220.00, 250.00, 150.00, 'Original: Si empezamos semi pensión es 220.00');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (248, 13, 2, 1, 1, 230.00, 250.00, 150.00, 'Original: Si empezamos semi pensión es 230.00');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (249, 13, 2, 2, 1, 220.00, 240.00, 150.00, 'Original: Si empezamos semi pensión es 220.00');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (250, 13, 3, 1, 1, 250.00, 280.00, 150.00, 'Original: Si empezamos semi pensión es 250.00');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (251, 14, 1, 1, 1, 260.00, 260.00, 150.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (252, 14, 2, 1, 1, 270.00, 270.00, 150.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (253, 14, 2, 2, 1, 270.00, 270.00, 150.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (254, 14, 3, 1, 1, 290.00, 290.00, 150.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (255, 15, 1, 1, 1, 300.00, 300.00, 150.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (256, 15, 2, 1, 1, 300.00, 300.00, 150.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (257, 15, 2, 2, 1, 300.00, 300.00, 150.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (258, 15, 3, 1, 1, 320.00, 320.00, 150.00, 'Original: Normal');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (259, 15, 1, 1, 2, 280.00, 280.00, 150.00, 'Original: DSCTO HNO 1');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (260, 15, 2, 1, 2, 280.00, 280.00, 150.00, 'Original: DSCTO HNO 1');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (261, 15, 2, 2, 2, 280.00, 280.00, 150.00, 'Original: DSCTO HNO 1');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (262, 15, 3, 1, 2, 300.00, 300.00, 150.00, 'Original: DSCTO HNO 1');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (263, 15, 1, 1, 3, 280.00, 280.00, 150.00, 'Original: DSCTO HNO 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (264, 15, 2, 1, 3, 280.00, 280.00, 150.00, 'Original: DSCTO HNO 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (265, 15, 2, 2, 3, 280.00, 280.00, 150.00, 'Original: DSCTO HNO 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (266, 15, 3, 1, 3, 300.00, 300.00, 150.00, 'Original: DSCTO HNO 2');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (267, 15, 1, 1, 4, 280.00, 280.00, 150.00, 'Original: DSCTO HNO 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (268, 15, 2, 1, 4, 280.00, 280.00, 150.00, 'Original: DSCTO HNO 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (269, 15, 2, 2, 4, 280.00, 280.00, 150.00, 'Original: DSCTO HNO 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (270, 15, 3, 1, 4, 300.00, 300.00, 150.00, 'Original: DSCTO HNO 3');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (271, 15, 1, 1, 5, 250.00, 250.00, 150.00, 'Original: DSCTO HIJO DE TRABAJADOR');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (272, 15, 2, 1, 5, 250.00, 250.00, 150.00, 'Original: DSCTO HIJO DE TRABAJADOR');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (273, 15, 2, 2, 5, 250.00, 250.00, 150.00, 'Original: DSCTO HIJO DE TRABAJADOR');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (274, 15, 3, 1, 5, 270.00, 270.00, 150.00, 'Original: DSCTO HIJO DE TRABAJADOR');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (275, 16, 1, 1, 1, 315.00, 315.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (276, 16, 1, 1, 2, 294.00, 294.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (277, 16, 1, 1, 3, 294.00, 294.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (278, 16, 1, 1, 4, 294.00, 294.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (279, 16, 1, 1, 5, 262.50, 262.50, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (280, 16, 2, 1, 1, 315.00, 315.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (281, 16, 2, 1, 2, 294.00, 294.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (282, 16, 2, 1, 3, 294.00, 294.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (283, 16, 2, 1, 4, 294.00, 294.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (284, 16, 2, 1, 5, 262.50, 262.50, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (285, 16, 2, 2, 1, 315.00, 315.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (286, 16, 2, 2, 2, 294.00, 294.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (287, 16, 2, 2, 3, 294.00, 294.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (288, 16, 2, 2, 4, 294.00, 294.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (289, 16, 2, 2, 5, 262.50, 262.50, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (290, 16, 3, 1, 1, 336.00, 336.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (291, 16, 3, 1, 2, 315.00, 315.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (292, 16, 3, 1, 3, 315.00, 315.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (293, 16, 3, 1, 4, 315.00, 315.00, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (294, 16, 3, 1, 5, 283.50, 283.50, 157.50, 'Generado desde año 15 con incremento 5.00%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (295, 17, 1, 1, 1, 330.75, 330.75, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (296, 17, 1, 1, 2, 308.70, 308.70, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (297, 17, 1, 1, 3, 308.70, 308.70, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (298, 17, 1, 1, 4, 308.70, 308.70, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (299, 17, 1, 1, 5, 275.63, 275.63, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (300, 17, 2, 1, 1, 330.75, 330.75, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (301, 17, 2, 1, 2, 308.70, 308.70, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (302, 17, 2, 1, 3, 308.70, 308.70, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (303, 17, 2, 1, 4, 308.70, 308.70, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (304, 17, 2, 1, 5, 275.63, 275.63, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (305, 17, 2, 2, 1, 330.75, 330.75, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (306, 17, 2, 2, 2, 308.70, 308.70, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (307, 17, 2, 2, 3, 308.70, 308.70, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (308, 17, 2, 2, 4, 308.70, 308.70, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (309, 17, 2, 2, 5, 275.63, 275.63, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (310, 17, 3, 1, 1, 352.80, 352.80, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (311, 17, 3, 1, 2, 330.75, 330.75, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (312, 17, 3, 1, 3, 330.75, 330.75, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (313, 17, 3, 1, 4, 330.75, 330.75, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (314, 17, 3, 1, 5, 297.68, 297.68, 165.38, 'Generado desde año 15 con incremento 10.25%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (315, 18, 1, 1, 1, 347.28, 347.28, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (316, 18, 1, 1, 2, 324.13, 324.13, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (317, 18, 1, 1, 3, 324.13, 324.13, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (318, 18, 1, 1, 4, 324.13, 324.13, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (319, 18, 1, 1, 5, 289.40, 289.40, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (320, 18, 2, 1, 1, 347.28, 347.28, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (321, 18, 2, 1, 2, 324.13, 324.13, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (322, 18, 2, 1, 3, 324.13, 324.13, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (323, 18, 2, 1, 4, 324.13, 324.13, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (324, 18, 2, 1, 5, 289.40, 289.40, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (325, 18, 2, 2, 1, 347.28, 347.28, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (326, 18, 2, 2, 2, 324.13, 324.13, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (327, 18, 2, 2, 3, 324.13, 324.13, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (328, 18, 2, 2, 4, 324.13, 324.13, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (329, 18, 2, 2, 5, 289.40, 289.40, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (330, 18, 3, 1, 1, 370.43, 370.43, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (331, 18, 3, 1, 2, 347.28, 347.28, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (332, 18, 3, 1, 3, 347.28, 347.28, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (333, 18, 3, 1, 4, 347.28, 347.28, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (334, 18, 3, 1, 5, 312.55, 312.55, 173.64, 'Generado desde año 15 con incremento 15.76%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (335, 19, 1, 1, 1, 364.65, 364.65, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (336, 19, 1, 1, 2, 340.34, 340.34, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (337, 19, 1, 1, 3, 340.34, 340.34, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (338, 19, 1, 1, 4, 340.34, 340.34, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (339, 19, 1, 1, 5, 303.88, 303.88, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (340, 19, 2, 1, 1, 364.65, 364.65, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (341, 19, 2, 1, 2, 340.34, 340.34, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (342, 19, 2, 1, 3, 340.34, 340.34, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (343, 19, 2, 1, 4, 340.34, 340.34, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (344, 19, 2, 1, 5, 303.88, 303.88, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (345, 19, 2, 2, 1, 364.65, 364.65, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (346, 19, 2, 2, 2, 340.34, 340.34, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (347, 19, 2, 2, 3, 340.34, 340.34, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (348, 19, 2, 2, 4, 340.34, 340.34, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (349, 19, 2, 2, 5, 303.88, 303.88, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (350, 19, 3, 1, 1, 388.96, 388.96, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (351, 19, 3, 1, 2, 364.65, 364.65, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (352, 19, 3, 1, 3, 364.65, 364.65, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (353, 19, 3, 1, 4, 364.65, 364.65, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (354, 19, 3, 1, 5, 328.19, 328.19, 182.33, 'Generado desde año 15 con incremento 21.55%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (355, 20, 1, 1, 1, 382.89, 382.89, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (356, 20, 1, 1, 2, 357.36, 357.36, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (357, 20, 1, 1, 3, 357.36, 357.36, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (358, 20, 1, 1, 4, 357.36, 357.36, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (359, 20, 1, 1, 5, 319.08, 319.08, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (360, 20, 2, 1, 1, 382.89, 382.89, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (361, 20, 2, 1, 2, 357.36, 357.36, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (362, 20, 2, 1, 3, 357.36, 357.36, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (363, 20, 2, 1, 4, 357.36, 357.36, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (364, 20, 2, 1, 5, 319.08, 319.08, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (365, 20, 2, 2, 1, 382.89, 382.89, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (366, 20, 2, 2, 2, 357.36, 357.36, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (367, 20, 2, 2, 3, 357.36, 357.36, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (368, 20, 2, 2, 4, 357.36, 357.36, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (369, 20, 2, 2, 5, 319.08, 319.08, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (370, 20, 3, 1, 1, 408.42, 408.42, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (371, 20, 3, 1, 2, 382.89, 382.89, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (372, 20, 3, 1, 3, 382.89, 382.89, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (373, 20, 3, 1, 4, 382.89, 382.89, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (374, 20, 3, 1, 5, 344.60, 344.60, 191.45, 'Generado desde año 15 con incremento 27.63%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (375, 21, 1, 1, 1, 402.03, 402.03, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (376, 21, 1, 1, 2, 375.23, 375.23, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (377, 21, 1, 1, 3, 375.23, 375.23, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (378, 21, 1, 1, 4, 375.23, 375.23, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (379, 21, 1, 1, 5, 335.03, 335.03, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (380, 21, 2, 1, 1, 402.03, 402.03, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (381, 21, 2, 1, 2, 375.23, 375.23, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (382, 21, 2, 1, 3, 375.23, 375.23, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (383, 21, 2, 1, 4, 375.23, 375.23, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (384, 21, 2, 1, 5, 335.03, 335.03, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (385, 21, 2, 2, 1, 402.03, 402.03, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (386, 21, 2, 2, 2, 375.23, 375.23, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (387, 21, 2, 2, 3, 375.23, 375.23, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (388, 21, 2, 2, 4, 375.23, 375.23, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (389, 21, 2, 2, 5, 335.03, 335.03, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (390, 21, 3, 1, 1, 428.83, 428.83, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (391, 21, 3, 1, 2, 402.03, 402.03, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (392, 21, 3, 1, 3, 402.03, 402.03, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (393, 21, 3, 1, 4, 402.03, 402.03, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (394, 21, 3, 1, 5, 361.83, 361.83, 201.02, 'Generado desde año 15 con incremento 34.01%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (395, 22, 1, 1, 1, 422.13, 422.13, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (396, 22, 1, 1, 2, 393.99, 393.99, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (397, 22, 1, 1, 3, 393.99, 393.99, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (398, 22, 1, 1, 4, 393.99, 393.99, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (399, 22, 1, 1, 5, 351.78, 351.78, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (400, 22, 2, 1, 1, 422.13, 422.13, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (401, 22, 2, 1, 2, 393.99, 393.99, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (402, 22, 2, 1, 3, 393.99, 393.99, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (403, 22, 2, 1, 4, 393.99, 393.99, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (404, 22, 2, 1, 5, 351.78, 351.78, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (405, 22, 2, 2, 1, 422.13, 422.13, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (406, 22, 2, 2, 2, 393.99, 393.99, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (407, 22, 2, 2, 3, 393.99, 393.99, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (408, 22, 2, 2, 4, 393.99, 393.99, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (409, 22, 2, 2, 5, 351.78, 351.78, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (410, 22, 3, 1, 1, 450.27, 450.27, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (411, 22, 3, 1, 2, 422.13, 422.13, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (412, 22, 3, 1, 3, 422.13, 422.13, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (413, 22, 3, 1, 4, 422.13, 422.13, 211.07, 'Generado desde año 15 con incremento 40.71%');
INSERT INTO public.school_fee (id, school_year_id, level_id, shift_id, school_fee_concept_id, enrollment_price, tuition_cost, registration_fee, description) VALUES (414, 22, 3, 1, 5, 379.92, 379.92, 211.07, 'Generado desde año 15 con incremento 40.71%');


--
-- Data for Name: school_fee_concepts; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.school_fee_concepts (id, name) VALUES (1, 'Normal');
INSERT INTO public.school_fee_concepts (id, name) VALUES (2, 'Dscto hermano 1');
INSERT INTO public.school_fee_concepts (id, name) VALUES (3, 'Dscto hermano 2');
INSERT INTO public.school_fee_concepts (id, name) VALUES (4, 'Dscto hermano 3');
INSERT INTO public.school_fee_concepts (id, name) VALUES (5, 'Dscto hijo de trabajador');


--
-- Data for Name: school_year; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (1, 2010, '2009-08-01', '2010-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (2, 2011, '2010-08-01', '2011-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (3, 2012, '2011-08-01', '2012-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (4, 2013, '2012-08-01', '2013-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (5, 2014, '2013-08-01', '2014-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (6, 2015, '2014-08-01', '2015-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (7, 2016, '2015-08-01', '2016-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (8, 2017, '2016-08-01', '2017-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (9, 2018, '2017-08-01', '2018-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (10, 2019, '2018-08-01', '2019-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (11, 2020, '2019-08-01', '2020-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (12, 2021, '2020-08-01', '2021-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (13, 2022, '2021-08-01', '2022-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (14, 2023, '2022-08-01', '2023-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (15, 2024, '2023-08-01', '2024-12-31', false);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (18, 2027, '2026-08-01', '2027-12-31', true);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (19, 2028, '2027-08-01', '2028-12-31', true);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (20, 2029, '2028-08-01', '2029-12-31', true);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (21, 2030, '2029-08-01', '2030-12-31', true);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (17, 2026, '2025-08-01', '2026-12-31', true);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (16, 2025, '2024-08-01', '2025-12-31', true);
INSERT INTO public.school_year (id, year, start_date, end_date, is_active) VALUES (22, 2031, '2030-08-01', '2031-12-31', true);


--
-- Data for Name: school_year_months; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (1, 1, 3, '2010-03-01', '2010-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (2, 1, 4, '2010-03-21', '2010-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (3, 1, 5, '2010-04-21', '2010-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (4, 1, 6, '2010-05-21', '2010-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (5, 1, 7, '2010-06-21', '2010-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (6, 1, 8, '2010-07-21', '2010-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (7, 1, 9, '2010-08-21', '2010-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (8, 1, 10, '2010-09-21', '2010-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (9, 1, 11, '2010-10-21', '2010-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (10, 1, 12, '2010-11-21', '2010-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (11, 2, 3, '2011-03-01', '2011-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (12, 2, 4, '2011-03-21', '2011-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (13, 2, 5, '2011-04-21', '2011-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (14, 2, 6, '2011-05-21', '2011-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (15, 2, 7, '2011-06-21', '2011-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (16, 2, 8, '2011-07-21', '2011-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (17, 2, 9, '2011-08-21', '2011-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (18, 2, 10, '2011-09-21', '2011-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (19, 2, 11, '2011-10-21', '2011-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (20, 2, 12, '2011-11-21', '2011-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (21, 3, 3, '2012-03-01', '2012-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (22, 3, 4, '2012-03-21', '2012-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (23, 3, 5, '2012-04-21', '2012-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (24, 3, 6, '2012-05-21', '2012-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (25, 3, 7, '2012-06-21', '2012-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (26, 3, 8, '2012-07-21', '2012-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (27, 3, 9, '2012-08-21', '2012-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (28, 3, 10, '2012-09-21', '2012-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (29, 3, 11, '2012-10-21', '2012-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (30, 3, 12, '2012-11-21', '2012-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (31, 4, 3, '2013-03-01', '2013-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (32, 4, 4, '2013-03-21', '2013-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (33, 4, 5, '2013-04-21', '2013-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (34, 4, 6, '2013-05-21', '2013-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (35, 4, 7, '2013-06-21', '2013-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (36, 4, 8, '2013-07-21', '2013-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (37, 4, 9, '2013-08-21', '2013-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (38, 4, 10, '2013-09-21', '2013-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (39, 4, 11, '2013-10-21', '2013-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (40, 4, 12, '2013-11-21', '2013-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (41, 5, 3, '2014-03-01', '2014-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (42, 5, 4, '2014-03-21', '2014-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (43, 5, 5, '2014-04-21', '2014-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (44, 5, 6, '2014-05-21', '2014-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (45, 5, 7, '2014-06-21', '2014-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (46, 5, 8, '2014-07-21', '2014-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (47, 5, 9, '2014-08-21', '2014-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (48, 5, 10, '2014-09-21', '2014-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (49, 5, 11, '2014-10-21', '2014-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (50, 5, 12, '2014-11-21', '2014-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (51, 6, 3, '2015-03-01', '2015-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (52, 6, 4, '2015-03-21', '2015-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (53, 6, 5, '2015-04-21', '2015-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (54, 6, 6, '2015-05-21', '2015-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (55, 6, 7, '2015-06-21', '2015-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (56, 6, 8, '2015-07-21', '2015-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (57, 6, 9, '2015-08-21', '2015-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (58, 6, 10, '2015-09-21', '2015-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (59, 6, 11, '2015-10-21', '2015-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (60, 6, 12, '2015-11-21', '2015-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (61, 7, 3, '2016-03-01', '2016-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (62, 7, 4, '2016-03-21', '2016-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (63, 7, 5, '2016-04-21', '2016-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (64, 7, 6, '2016-05-21', '2016-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (65, 7, 7, '2016-06-21', '2016-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (66, 7, 8, '2016-07-21', '2016-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (67, 7, 9, '2016-08-21', '2016-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (68, 7, 10, '2016-09-21', '2016-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (69, 7, 11, '2016-10-21', '2016-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (70, 7, 12, '2016-11-21', '2016-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (71, 8, 3, '2017-03-01', '2017-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (72, 8, 4, '2017-03-21', '2017-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (73, 8, 5, '2017-04-21', '2017-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (74, 8, 6, '2017-05-21', '2017-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (75, 8, 7, '2017-06-21', '2017-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (76, 8, 8, '2017-07-21', '2017-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (77, 8, 9, '2017-08-21', '2017-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (78, 8, 10, '2017-09-21', '2017-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (79, 8, 11, '2017-10-21', '2017-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (80, 8, 12, '2017-11-21', '2017-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (81, 9, 3, '2018-03-01', '2018-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (82, 9, 4, '2018-03-21', '2018-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (83, 9, 5, '2018-04-21', '2018-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (84, 9, 6, '2018-05-21', '2018-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (85, 9, 7, '2018-06-21', '2018-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (86, 9, 8, '2018-07-21', '2018-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (87, 9, 9, '2018-08-21', '2018-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (88, 9, 10, '2018-09-21', '2018-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (89, 9, 11, '2018-10-21', '2018-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (90, 9, 12, '2018-11-21', '2018-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (91, 10, 3, '2019-03-01', '2019-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (92, 10, 4, '2019-03-21', '2019-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (93, 10, 5, '2019-04-21', '2019-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (94, 10, 6, '2019-05-21', '2019-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (95, 10, 7, '2019-06-21', '2019-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (96, 10, 8, '2019-07-21', '2019-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (97, 10, 9, '2019-08-21', '2019-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (98, 10, 10, '2019-09-21', '2019-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (99, 10, 11, '2019-10-21', '2019-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (100, 10, 12, '2019-11-21', '2019-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (101, 11, 3, '2020-03-01', '2020-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (102, 11, 4, '2020-03-21', '2020-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (103, 11, 5, '2020-04-21', '2020-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (104, 11, 6, '2020-05-21', '2020-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (105, 11, 7, '2020-06-21', '2020-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (106, 11, 8, '2020-07-21', '2020-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (107, 11, 9, '2020-08-21', '2020-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (108, 11, 10, '2020-09-21', '2020-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (109, 11, 11, '2020-10-21', '2020-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (110, 11, 12, '2020-11-21', '2020-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (111, 12, 3, '2021-03-01', '2021-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (112, 12, 4, '2021-03-21', '2021-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (113, 12, 5, '2021-04-21', '2021-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (114, 12, 6, '2021-05-21', '2021-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (115, 12, 7, '2021-06-21', '2021-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (116, 12, 8, '2021-07-21', '2021-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (117, 12, 9, '2021-08-21', '2021-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (118, 12, 10, '2021-09-21', '2021-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (119, 12, 11, '2021-10-21', '2021-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (120, 12, 12, '2021-11-21', '2021-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (121, 13, 3, '2022-03-01', '2022-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (122, 13, 4, '2022-03-21', '2022-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (123, 13, 5, '2022-04-21', '2022-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (124, 13, 6, '2022-05-21', '2022-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (125, 13, 7, '2022-06-21', '2022-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (126, 13, 8, '2022-07-21', '2022-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (127, 13, 9, '2022-08-21', '2022-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (128, 13, 10, '2022-09-21', '2022-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (129, 13, 11, '2022-10-21', '2022-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (130, 13, 12, '2022-11-21', '2022-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (131, 14, 3, '2023-03-01', '2023-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (132, 14, 4, '2023-03-21', '2023-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (133, 14, 5, '2023-04-21', '2023-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (134, 14, 6, '2023-05-21', '2023-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (135, 14, 7, '2023-06-21', '2023-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (136, 14, 8, '2023-07-21', '2023-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (137, 14, 9, '2023-08-21', '2023-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (138, 14, 10, '2023-09-21', '2023-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (139, 14, 11, '2023-10-21', '2023-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (140, 14, 12, '2023-11-21', '2023-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (141, 15, 3, '2024-03-01', '2024-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (142, 15, 4, '2024-03-21', '2024-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (143, 15, 5, '2024-04-21', '2024-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (144, 15, 6, '2024-05-21', '2024-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (145, 15, 7, '2024-06-21', '2024-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (146, 15, 8, '2024-07-21', '2024-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (147, 15, 9, '2024-08-21', '2024-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (148, 15, 10, '2024-09-21', '2024-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (149, 15, 11, '2024-10-21', '2024-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (150, 15, 12, '2024-11-21', '2024-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (151, 16, 3, '2025-03-01', '2025-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (152, 16, 4, '2025-03-21', '2025-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (153, 16, 5, '2025-04-21', '2025-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (154, 16, 6, '2025-05-21', '2025-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (155, 16, 7, '2025-06-21', '2025-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (156, 16, 8, '2025-07-21', '2025-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (157, 16, 9, '2025-08-21', '2025-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (158, 16, 10, '2025-09-21', '2025-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (159, 16, 11, '2025-10-21', '2025-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (160, 16, 12, '2025-11-21', '2025-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (161, 17, 3, '2026-03-01', '2026-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (162, 17, 4, '2026-03-21', '2026-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (165, 17, 7, '2026-06-21', '2026-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (166, 17, 8, '2026-07-21', '2026-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (167, 17, 9, '2026-08-21', '2026-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (168, 17, 10, '2026-09-21', '2026-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (169, 17, 11, '2026-10-21', '2026-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (170, 17, 12, '2026-11-21', '2026-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (171, 18, 3, '2027-03-01', '2027-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (172, 18, 4, '2027-03-21', '2027-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (173, 18, 5, '2027-04-21', '2027-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (174, 18, 6, '2027-05-21', '2027-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (175, 18, 7, '2027-06-21', '2027-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (176, 18, 8, '2027-07-21', '2027-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (177, 18, 9, '2027-08-21', '2027-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (178, 18, 10, '2027-09-21', '2027-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (179, 18, 11, '2027-10-21', '2027-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (180, 18, 12, '2027-11-21', '2027-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (181, 19, 3, '2028-03-01', '2028-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (182, 19, 4, '2028-03-21', '2028-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (183, 19, 5, '2028-04-21', '2028-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (184, 19, 6, '2028-05-21', '2028-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (185, 19, 7, '2028-06-21', '2028-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (186, 19, 8, '2028-07-21', '2028-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (187, 19, 9, '2028-08-21', '2028-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (188, 19, 10, '2028-09-21', '2028-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (189, 19, 11, '2028-10-21', '2028-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (190, 19, 12, '2028-11-21', '2028-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (191, 20, 3, '2029-03-01', '2029-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (192, 20, 4, '2029-03-21', '2029-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (193, 20, 5, '2029-04-21', '2029-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (194, 20, 6, '2029-05-21', '2029-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (195, 20, 7, '2029-06-21', '2029-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (196, 20, 8, '2029-07-21', '2029-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (197, 20, 9, '2029-08-21', '2029-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (198, 20, 10, '2029-09-21', '2029-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (199, 20, 11, '2029-10-21', '2029-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (200, 20, 12, '2029-11-21', '2029-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (201, 21, 3, '2030-03-01', '2030-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (202, 21, 4, '2030-03-21', '2030-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (203, 21, 5, '2030-04-21', '2030-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (204, 21, 6, '2030-05-21', '2030-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (205, 21, 7, '2030-06-21', '2030-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (206, 21, 8, '2030-07-21', '2030-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (207, 21, 9, '2030-08-21', '2030-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (208, 21, 10, '2030-09-21', '2030-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (209, 21, 11, '2030-10-21', '2030-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (210, 21, 12, '2030-11-21', '2030-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (211, 22, 3, '2031-03-01', '2031-03-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (212, 22, 4, '2031-03-21', '2031-04-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (213, 22, 5, '2031-04-21', '2031-05-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (214, 22, 6, '2031-05-21', '2031-06-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (215, 22, 7, '2031-06-21', '2031-07-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (216, 22, 8, '2031-07-21', '2031-08-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (217, 22, 9, '2031-08-21', '2031-09-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (218, 22, 10, '2031-09-21', '2031-10-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (219, 22, 11, '2031-10-21', '2031-11-30', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (220, 22, 12, '2031-11-21', '2031-12-31', false);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (163, 17, 5, '2026-04-21', '2026-05-31', true);
INSERT INTO public.school_year_months (id, school_year_id, month, billing_open_date, due_date, is_active) OVERRIDING SYSTEM VALUE VALUES (164, 17, 6, '2026-05-21', '2026-06-30', true);


--
-- Data for Name: second_languages; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.second_languages (person_id, second_language_id) VALUES (37, 13);
INSERT INTO public.second_languages (person_id, second_language_id) VALUES (38, 16);
INSERT INTO public.second_languages (person_id, second_language_id) VALUES (45, 16);
INSERT INTO public.second_languages (person_id, second_language_id) VALUES (45, 17);
INSERT INTO public.second_languages (person_id, second_language_id) VALUES (45, 19);
INSERT INTO public.second_languages (person_id, second_language_id) VALUES (46, 2);
INSERT INTO public.second_languages (person_id, second_language_id) VALUES (46, 11);
INSERT INTO public.second_languages (person_id, second_language_id) VALUES (47, 16);
INSERT INTO public.second_languages (person_id, second_language_id) VALUES (47, 17);


--
-- Data for Name: shifts; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.shifts (id, name) VALUES (1, 'mañana');
INSERT INTO public.shifts (id, name) VALUES (2, 'tarde');


--
-- Data for Name: staff_members; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.staff_members (person_id, level_of_education_id, professional_title, employee_code, previous_institution, spouse_name, spouse_document_number, spouse_occupation, number_of_children, comment, is_active, is_archived) VALUES (43, 12, 'Ingeniero en Turismo', 'E00-1', 'Institucion de prueba', 'Conyuge 43', '00000043', 'Ocupacion de prueba', 3, NULL, true, false);
INSERT INTO public.staff_members (person_id, level_of_education_id, professional_title, employee_code, previous_institution, spouse_name, spouse_document_number, spouse_occupation, number_of_children, comment, is_active, is_archived) VALUES (48, 22, 'Ingeniero en Turismo', 'E00-2', NULL, NULL, NULL, NULL, NULL, NULL, true, false);


--
-- Data for Name: student_homes; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.student_homes (student_id, has_electronic_devices, has_internet_access) VALUES (37, true, true);
INSERT INTO public.student_homes (student_id, has_electronic_devices, has_internet_access) VALUES (39, true, true);
INSERT INTO public.student_homes (student_id, has_electronic_devices, has_internet_access) VALUES (41, true, true);
INSERT INTO public.student_homes (student_id, has_electronic_devices, has_internet_access) VALUES (44, true, true);
INSERT INTO public.student_homes (student_id, has_electronic_devices, has_internet_access) VALUES (46, true, true);


--
-- Data for Name: student_school_year_states; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.student_school_year_states (id, name, description) VALUES (1, 'Pendiente de matricula', 'Aun no se ha matriculado en el año escolar actual');
INSERT INTO public.student_school_year_states (id, name, description) VALUES (4, 'No matriculado', 'Pasó el año escolar, y el estudiante no se matriculó');
INSERT INTO public.student_school_year_states (id, name, description) VALUES (2, 'Matriculado', '');


--
-- Data for Name: student_school_years; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.students (person_id, birth_ubigeo_id, has_disability, siblings, childbirth_type_id, is_active, birth_order, is_archived) VALUES (39, 836, false, 19, 1, true, 1, false);
INSERT INTO public.students (person_id, birth_ubigeo_id, has_disability, siblings, childbirth_type_id, is_active, birth_order, is_archived) VALUES (41, 1160, false, 9, 1, false, 1, false);
INSERT INTO public.students (person_id, birth_ubigeo_id, has_disability, siblings, childbirth_type_id, is_active, birth_order, is_archived) VALUES (37, 1160, false, 13, 1, true, 1, false);
INSERT INTO public.students (person_id, birth_ubigeo_id, has_disability, siblings, childbirth_type_id, is_active, birth_order, is_archived) VALUES (44, 1809, false, 45, 1, false, 1, false);
INSERT INTO public.students (person_id, birth_ubigeo_id, has_disability, siblings, childbirth_type_id, is_active, birth_order, is_archived) VALUES (46, 1160, false, 4, 1, false, 1, false);


--
-- Data for Name: ubigeo; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.ubigeo (district_id, code) VALUES (1, '010101');
INSERT INTO public.ubigeo (district_id, code) VALUES (2, '010102');
INSERT INTO public.ubigeo (district_id, code) VALUES (3, '010103');
INSERT INTO public.ubigeo (district_id, code) VALUES (4, '010104');
INSERT INTO public.ubigeo (district_id, code) VALUES (5, '010105');
INSERT INTO public.ubigeo (district_id, code) VALUES (6, '010106');
INSERT INTO public.ubigeo (district_id, code) VALUES (7, '010107');
INSERT INTO public.ubigeo (district_id, code) VALUES (8, '010108');
INSERT INTO public.ubigeo (district_id, code) VALUES (9, '010109');
INSERT INTO public.ubigeo (district_id, code) VALUES (10, '010110');
INSERT INTO public.ubigeo (district_id, code) VALUES (11, '010111');
INSERT INTO public.ubigeo (district_id, code) VALUES (12, '010112');
INSERT INTO public.ubigeo (district_id, code) VALUES (13, '010113');
INSERT INTO public.ubigeo (district_id, code) VALUES (14, '010114');
INSERT INTO public.ubigeo (district_id, code) VALUES (15, '010115');
INSERT INTO public.ubigeo (district_id, code) VALUES (16, '010116');
INSERT INTO public.ubigeo (district_id, code) VALUES (17, '010117');
INSERT INTO public.ubigeo (district_id, code) VALUES (18, '010118');
INSERT INTO public.ubigeo (district_id, code) VALUES (19, '010119');
INSERT INTO public.ubigeo (district_id, code) VALUES (20, '010120');
INSERT INTO public.ubigeo (district_id, code) VALUES (21, '010121');
INSERT INTO public.ubigeo (district_id, code) VALUES (22, '010201');
INSERT INTO public.ubigeo (district_id, code) VALUES (23, '010202');
INSERT INTO public.ubigeo (district_id, code) VALUES (24, '010203');
INSERT INTO public.ubigeo (district_id, code) VALUES (25, '010204');
INSERT INTO public.ubigeo (district_id, code) VALUES (26, '010205');
INSERT INTO public.ubigeo (district_id, code) VALUES (27, '010206');
INSERT INTO public.ubigeo (district_id, code) VALUES (28, '010301');
INSERT INTO public.ubigeo (district_id, code) VALUES (29, '010302');
INSERT INTO public.ubigeo (district_id, code) VALUES (30, '010303');
INSERT INTO public.ubigeo (district_id, code) VALUES (31, '010304');
INSERT INTO public.ubigeo (district_id, code) VALUES (32, '010305');
INSERT INTO public.ubigeo (district_id, code) VALUES (33, '010306');
INSERT INTO public.ubigeo (district_id, code) VALUES (34, '010307');
INSERT INTO public.ubigeo (district_id, code) VALUES (35, '010308');
INSERT INTO public.ubigeo (district_id, code) VALUES (36, '010309');
INSERT INTO public.ubigeo (district_id, code) VALUES (37, '010310');
INSERT INTO public.ubigeo (district_id, code) VALUES (38, '010311');
INSERT INTO public.ubigeo (district_id, code) VALUES (39, '010312');
INSERT INTO public.ubigeo (district_id, code) VALUES (40, '010401');
INSERT INTO public.ubigeo (district_id, code) VALUES (41, '010402');
INSERT INTO public.ubigeo (district_id, code) VALUES (42, '010403');
INSERT INTO public.ubigeo (district_id, code) VALUES (43, '010501');
INSERT INTO public.ubigeo (district_id, code) VALUES (44, '010502');
INSERT INTO public.ubigeo (district_id, code) VALUES (45, '010503');
INSERT INTO public.ubigeo (district_id, code) VALUES (46, '010504');
INSERT INTO public.ubigeo (district_id, code) VALUES (47, '010505');
INSERT INTO public.ubigeo (district_id, code) VALUES (48, '010506');
INSERT INTO public.ubigeo (district_id, code) VALUES (49, '010507');
INSERT INTO public.ubigeo (district_id, code) VALUES (50, '010508');
INSERT INTO public.ubigeo (district_id, code) VALUES (51, '010509');
INSERT INTO public.ubigeo (district_id, code) VALUES (52, '010510');
INSERT INTO public.ubigeo (district_id, code) VALUES (53, '010511');
INSERT INTO public.ubigeo (district_id, code) VALUES (54, '010512');
INSERT INTO public.ubigeo (district_id, code) VALUES (55, '010513');
INSERT INTO public.ubigeo (district_id, code) VALUES (56, '010514');
INSERT INTO public.ubigeo (district_id, code) VALUES (57, '010515');
INSERT INTO public.ubigeo (district_id, code) VALUES (58, '010516');
INSERT INTO public.ubigeo (district_id, code) VALUES (59, '010517');
INSERT INTO public.ubigeo (district_id, code) VALUES (60, '010518');
INSERT INTO public.ubigeo (district_id, code) VALUES (61, '010519');
INSERT INTO public.ubigeo (district_id, code) VALUES (62, '010520');
INSERT INTO public.ubigeo (district_id, code) VALUES (63, '010521');
INSERT INTO public.ubigeo (district_id, code) VALUES (64, '010522');
INSERT INTO public.ubigeo (district_id, code) VALUES (65, '010523');
INSERT INTO public.ubigeo (district_id, code) VALUES (66, '010601');
INSERT INTO public.ubigeo (district_id, code) VALUES (67, '010602');
INSERT INTO public.ubigeo (district_id, code) VALUES (68, '010603');
INSERT INTO public.ubigeo (district_id, code) VALUES (69, '010604');
INSERT INTO public.ubigeo (district_id, code) VALUES (70, '010605');
INSERT INTO public.ubigeo (district_id, code) VALUES (71, '010606');
INSERT INTO public.ubigeo (district_id, code) VALUES (72, '010607');
INSERT INTO public.ubigeo (district_id, code) VALUES (73, '010608');
INSERT INTO public.ubigeo (district_id, code) VALUES (74, '010609');
INSERT INTO public.ubigeo (district_id, code) VALUES (75, '010610');
INSERT INTO public.ubigeo (district_id, code) VALUES (76, '010611');
INSERT INTO public.ubigeo (district_id, code) VALUES (77, '010612');
INSERT INTO public.ubigeo (district_id, code) VALUES (78, '010701');
INSERT INTO public.ubigeo (district_id, code) VALUES (79, '010702');
INSERT INTO public.ubigeo (district_id, code) VALUES (80, '010703');
INSERT INTO public.ubigeo (district_id, code) VALUES (81, '010704');
INSERT INTO public.ubigeo (district_id, code) VALUES (82, '010705');
INSERT INTO public.ubigeo (district_id, code) VALUES (83, '010706');
INSERT INTO public.ubigeo (district_id, code) VALUES (84, '010707');
INSERT INTO public.ubigeo (district_id, code) VALUES (85, '020101');
INSERT INTO public.ubigeo (district_id, code) VALUES (86, '020102');
INSERT INTO public.ubigeo (district_id, code) VALUES (87, '020103');
INSERT INTO public.ubigeo (district_id, code) VALUES (88, '020104');
INSERT INTO public.ubigeo (district_id, code) VALUES (89, '020105');
INSERT INTO public.ubigeo (district_id, code) VALUES (90, '020106');
INSERT INTO public.ubigeo (district_id, code) VALUES (91, '020107');
INSERT INTO public.ubigeo (district_id, code) VALUES (92, '020108');
INSERT INTO public.ubigeo (district_id, code) VALUES (93, '020109');
INSERT INTO public.ubigeo (district_id, code) VALUES (94, '020110');
INSERT INTO public.ubigeo (district_id, code) VALUES (95, '020111');
INSERT INTO public.ubigeo (district_id, code) VALUES (96, '020112');
INSERT INTO public.ubigeo (district_id, code) VALUES (97, '020201');
INSERT INTO public.ubigeo (district_id, code) VALUES (98, '020202');
INSERT INTO public.ubigeo (district_id, code) VALUES (99, '020203');
INSERT INTO public.ubigeo (district_id, code) VALUES (100, '020204');
INSERT INTO public.ubigeo (district_id, code) VALUES (101, '020205');
INSERT INTO public.ubigeo (district_id, code) VALUES (102, '020301');
INSERT INTO public.ubigeo (district_id, code) VALUES (103, '020302');
INSERT INTO public.ubigeo (district_id, code) VALUES (104, '020303');
INSERT INTO public.ubigeo (district_id, code) VALUES (105, '020304');
INSERT INTO public.ubigeo (district_id, code) VALUES (106, '020305');
INSERT INTO public.ubigeo (district_id, code) VALUES (107, '020306');
INSERT INTO public.ubigeo (district_id, code) VALUES (108, '020401');
INSERT INTO public.ubigeo (district_id, code) VALUES (109, '020402');
INSERT INTO public.ubigeo (district_id, code) VALUES (110, '020501');
INSERT INTO public.ubigeo (district_id, code) VALUES (111, '020502');
INSERT INTO public.ubigeo (district_id, code) VALUES (112, '020503');
INSERT INTO public.ubigeo (district_id, code) VALUES (113, '020504');
INSERT INTO public.ubigeo (district_id, code) VALUES (114, '020505');
INSERT INTO public.ubigeo (district_id, code) VALUES (115, '020506');
INSERT INTO public.ubigeo (district_id, code) VALUES (116, '020507');
INSERT INTO public.ubigeo (district_id, code) VALUES (117, '020508');
INSERT INTO public.ubigeo (district_id, code) VALUES (118, '020509');
INSERT INTO public.ubigeo (district_id, code) VALUES (119, '020510');
INSERT INTO public.ubigeo (district_id, code) VALUES (120, '020511');
INSERT INTO public.ubigeo (district_id, code) VALUES (121, '020512');
INSERT INTO public.ubigeo (district_id, code) VALUES (122, '020513');
INSERT INTO public.ubigeo (district_id, code) VALUES (123, '020514');
INSERT INTO public.ubigeo (district_id, code) VALUES (124, '020515');
INSERT INTO public.ubigeo (district_id, code) VALUES (125, '020601');
INSERT INTO public.ubigeo (district_id, code) VALUES (126, '020602');
INSERT INTO public.ubigeo (district_id, code) VALUES (127, '020603');
INSERT INTO public.ubigeo (district_id, code) VALUES (128, '020604');
INSERT INTO public.ubigeo (district_id, code) VALUES (129, '020605');
INSERT INTO public.ubigeo (district_id, code) VALUES (130, '020606');
INSERT INTO public.ubigeo (district_id, code) VALUES (131, '020607');
INSERT INTO public.ubigeo (district_id, code) VALUES (132, '020608');
INSERT INTO public.ubigeo (district_id, code) VALUES (133, '020609');
INSERT INTO public.ubigeo (district_id, code) VALUES (134, '020610');
INSERT INTO public.ubigeo (district_id, code) VALUES (135, '020611');
INSERT INTO public.ubigeo (district_id, code) VALUES (136, '020701');
INSERT INTO public.ubigeo (district_id, code) VALUES (137, '020702');
INSERT INTO public.ubigeo (district_id, code) VALUES (138, '020703');
INSERT INTO public.ubigeo (district_id, code) VALUES (139, '020801');
INSERT INTO public.ubigeo (district_id, code) VALUES (140, '020802');
INSERT INTO public.ubigeo (district_id, code) VALUES (141, '020803');
INSERT INTO public.ubigeo (district_id, code) VALUES (142, '020804');
INSERT INTO public.ubigeo (district_id, code) VALUES (143, '020901');
INSERT INTO public.ubigeo (district_id, code) VALUES (144, '020902');
INSERT INTO public.ubigeo (district_id, code) VALUES (145, '020903');
INSERT INTO public.ubigeo (district_id, code) VALUES (146, '020904');
INSERT INTO public.ubigeo (district_id, code) VALUES (147, '020905');
INSERT INTO public.ubigeo (district_id, code) VALUES (148, '020906');
INSERT INTO public.ubigeo (district_id, code) VALUES (149, '020907');
INSERT INTO public.ubigeo (district_id, code) VALUES (150, '021001');
INSERT INTO public.ubigeo (district_id, code) VALUES (151, '021002');
INSERT INTO public.ubigeo (district_id, code) VALUES (152, '021003');
INSERT INTO public.ubigeo (district_id, code) VALUES (153, '021004');
INSERT INTO public.ubigeo (district_id, code) VALUES (154, '021005');
INSERT INTO public.ubigeo (district_id, code) VALUES (155, '021006');
INSERT INTO public.ubigeo (district_id, code) VALUES (156, '021007');
INSERT INTO public.ubigeo (district_id, code) VALUES (157, '021008');
INSERT INTO public.ubigeo (district_id, code) VALUES (158, '021009');
INSERT INTO public.ubigeo (district_id, code) VALUES (159, '021010');
INSERT INTO public.ubigeo (district_id, code) VALUES (160, '021011');
INSERT INTO public.ubigeo (district_id, code) VALUES (161, '021012');
INSERT INTO public.ubigeo (district_id, code) VALUES (162, '021013');
INSERT INTO public.ubigeo (district_id, code) VALUES (163, '021014');
INSERT INTO public.ubigeo (district_id, code) VALUES (164, '021015');
INSERT INTO public.ubigeo (district_id, code) VALUES (165, '021016');
INSERT INTO public.ubigeo (district_id, code) VALUES (166, '021101');
INSERT INTO public.ubigeo (district_id, code) VALUES (167, '021102');
INSERT INTO public.ubigeo (district_id, code) VALUES (168, '021103');
INSERT INTO public.ubigeo (district_id, code) VALUES (169, '021104');
INSERT INTO public.ubigeo (district_id, code) VALUES (170, '021105');
INSERT INTO public.ubigeo (district_id, code) VALUES (171, '021201');
INSERT INTO public.ubigeo (district_id, code) VALUES (172, '021202');
INSERT INTO public.ubigeo (district_id, code) VALUES (173, '021203');
INSERT INTO public.ubigeo (district_id, code) VALUES (174, '021204');
INSERT INTO public.ubigeo (district_id, code) VALUES (175, '021205');
INSERT INTO public.ubigeo (district_id, code) VALUES (176, '021206');
INSERT INTO public.ubigeo (district_id, code) VALUES (177, '021207');
INSERT INTO public.ubigeo (district_id, code) VALUES (178, '021208');
INSERT INTO public.ubigeo (district_id, code) VALUES (179, '021209');
INSERT INTO public.ubigeo (district_id, code) VALUES (180, '021210');
INSERT INTO public.ubigeo (district_id, code) VALUES (181, '021301');
INSERT INTO public.ubigeo (district_id, code) VALUES (182, '021302');
INSERT INTO public.ubigeo (district_id, code) VALUES (183, '021303');
INSERT INTO public.ubigeo (district_id, code) VALUES (184, '021304');
INSERT INTO public.ubigeo (district_id, code) VALUES (185, '021305');
INSERT INTO public.ubigeo (district_id, code) VALUES (186, '021306');
INSERT INTO public.ubigeo (district_id, code) VALUES (187, '021307');
INSERT INTO public.ubigeo (district_id, code) VALUES (188, '021308');
INSERT INTO public.ubigeo (district_id, code) VALUES (189, '021401');
INSERT INTO public.ubigeo (district_id, code) VALUES (190, '021402');
INSERT INTO public.ubigeo (district_id, code) VALUES (191, '021403');
INSERT INTO public.ubigeo (district_id, code) VALUES (192, '021404');
INSERT INTO public.ubigeo (district_id, code) VALUES (193, '021405');
INSERT INTO public.ubigeo (district_id, code) VALUES (194, '021406');
INSERT INTO public.ubigeo (district_id, code) VALUES (195, '021407');
INSERT INTO public.ubigeo (district_id, code) VALUES (196, '021408');
INSERT INTO public.ubigeo (district_id, code) VALUES (197, '021409');
INSERT INTO public.ubigeo (district_id, code) VALUES (198, '021410');
INSERT INTO public.ubigeo (district_id, code) VALUES (199, '021501');
INSERT INTO public.ubigeo (district_id, code) VALUES (200, '021502');
INSERT INTO public.ubigeo (district_id, code) VALUES (201, '021503');
INSERT INTO public.ubigeo (district_id, code) VALUES (202, '021504');
INSERT INTO public.ubigeo (district_id, code) VALUES (203, '021505');
INSERT INTO public.ubigeo (district_id, code) VALUES (204, '021506');
INSERT INTO public.ubigeo (district_id, code) VALUES (205, '021507');
INSERT INTO public.ubigeo (district_id, code) VALUES (206, '021508');
INSERT INTO public.ubigeo (district_id, code) VALUES (207, '021509');
INSERT INTO public.ubigeo (district_id, code) VALUES (208, '021510');
INSERT INTO public.ubigeo (district_id, code) VALUES (209, '021511');
INSERT INTO public.ubigeo (district_id, code) VALUES (210, '021601');
INSERT INTO public.ubigeo (district_id, code) VALUES (211, '021602');
INSERT INTO public.ubigeo (district_id, code) VALUES (212, '021603');
INSERT INTO public.ubigeo (district_id, code) VALUES (213, '021604');
INSERT INTO public.ubigeo (district_id, code) VALUES (214, '021701');
INSERT INTO public.ubigeo (district_id, code) VALUES (215, '021702');
INSERT INTO public.ubigeo (district_id, code) VALUES (216, '021703');
INSERT INTO public.ubigeo (district_id, code) VALUES (217, '021704');
INSERT INTO public.ubigeo (district_id, code) VALUES (218, '021705');
INSERT INTO public.ubigeo (district_id, code) VALUES (219, '021706');
INSERT INTO public.ubigeo (district_id, code) VALUES (220, '021707');
INSERT INTO public.ubigeo (district_id, code) VALUES (221, '021708');
INSERT INTO public.ubigeo (district_id, code) VALUES (222, '021709');
INSERT INTO public.ubigeo (district_id, code) VALUES (223, '021710');
INSERT INTO public.ubigeo (district_id, code) VALUES (224, '021801');
INSERT INTO public.ubigeo (district_id, code) VALUES (225, '021802');
INSERT INTO public.ubigeo (district_id, code) VALUES (226, '021803');
INSERT INTO public.ubigeo (district_id, code) VALUES (227, '021804');
INSERT INTO public.ubigeo (district_id, code) VALUES (228, '021805');
INSERT INTO public.ubigeo (district_id, code) VALUES (229, '021806');
INSERT INTO public.ubigeo (district_id, code) VALUES (230, '021807');
INSERT INTO public.ubigeo (district_id, code) VALUES (231, '021808');
INSERT INTO public.ubigeo (district_id, code) VALUES (232, '021809');
INSERT INTO public.ubigeo (district_id, code) VALUES (233, '021901');
INSERT INTO public.ubigeo (district_id, code) VALUES (234, '021902');
INSERT INTO public.ubigeo (district_id, code) VALUES (235, '021903');
INSERT INTO public.ubigeo (district_id, code) VALUES (236, '021904');
INSERT INTO public.ubigeo (district_id, code) VALUES (237, '021905');
INSERT INTO public.ubigeo (district_id, code) VALUES (238, '021906');
INSERT INTO public.ubigeo (district_id, code) VALUES (239, '021907');
INSERT INTO public.ubigeo (district_id, code) VALUES (240, '021908');
INSERT INTO public.ubigeo (district_id, code) VALUES (241, '021909');
INSERT INTO public.ubigeo (district_id, code) VALUES (242, '021910');
INSERT INTO public.ubigeo (district_id, code) VALUES (243, '022001');
INSERT INTO public.ubigeo (district_id, code) VALUES (244, '022002');
INSERT INTO public.ubigeo (district_id, code) VALUES (245, '022003');
INSERT INTO public.ubigeo (district_id, code) VALUES (246, '022004');
INSERT INTO public.ubigeo (district_id, code) VALUES (247, '022005');
INSERT INTO public.ubigeo (district_id, code) VALUES (248, '022006');
INSERT INTO public.ubigeo (district_id, code) VALUES (249, '022007');
INSERT INTO public.ubigeo (district_id, code) VALUES (250, '022008');
INSERT INTO public.ubigeo (district_id, code) VALUES (251, '030101');
INSERT INTO public.ubigeo (district_id, code) VALUES (252, '030102');
INSERT INTO public.ubigeo (district_id, code) VALUES (253, '030103');
INSERT INTO public.ubigeo (district_id, code) VALUES (254, '030104');
INSERT INTO public.ubigeo (district_id, code) VALUES (255, '030105');
INSERT INTO public.ubigeo (district_id, code) VALUES (256, '030106');
INSERT INTO public.ubigeo (district_id, code) VALUES (257, '030107');
INSERT INTO public.ubigeo (district_id, code) VALUES (258, '030108');
INSERT INTO public.ubigeo (district_id, code) VALUES (259, '030109');
INSERT INTO public.ubigeo (district_id, code) VALUES (260, '030201');
INSERT INTO public.ubigeo (district_id, code) VALUES (261, '030202');
INSERT INTO public.ubigeo (district_id, code) VALUES (262, '030203');
INSERT INTO public.ubigeo (district_id, code) VALUES (263, '030204');
INSERT INTO public.ubigeo (district_id, code) VALUES (264, '030205');
INSERT INTO public.ubigeo (district_id, code) VALUES (265, '030206');
INSERT INTO public.ubigeo (district_id, code) VALUES (266, '030207');
INSERT INTO public.ubigeo (district_id, code) VALUES (267, '030208');
INSERT INTO public.ubigeo (district_id, code) VALUES (268, '030209');
INSERT INTO public.ubigeo (district_id, code) VALUES (269, '030210');
INSERT INTO public.ubigeo (district_id, code) VALUES (270, '030211');
INSERT INTO public.ubigeo (district_id, code) VALUES (271, '030212');
INSERT INTO public.ubigeo (district_id, code) VALUES (272, '030213');
INSERT INTO public.ubigeo (district_id, code) VALUES (273, '030214');
INSERT INTO public.ubigeo (district_id, code) VALUES (274, '030215');
INSERT INTO public.ubigeo (district_id, code) VALUES (275, '030216');
INSERT INTO public.ubigeo (district_id, code) VALUES (276, '030217');
INSERT INTO public.ubigeo (district_id, code) VALUES (277, '030218');
INSERT INTO public.ubigeo (district_id, code) VALUES (278, '030219');
INSERT INTO public.ubigeo (district_id, code) VALUES (279, '030220');
INSERT INTO public.ubigeo (district_id, code) VALUES (280, '030301');
INSERT INTO public.ubigeo (district_id, code) VALUES (281, '030302');
INSERT INTO public.ubigeo (district_id, code) VALUES (282, '030303');
INSERT INTO public.ubigeo (district_id, code) VALUES (283, '030304');
INSERT INTO public.ubigeo (district_id, code) VALUES (284, '030305');
INSERT INTO public.ubigeo (district_id, code) VALUES (285, '030306');
INSERT INTO public.ubigeo (district_id, code) VALUES (286, '030307');
INSERT INTO public.ubigeo (district_id, code) VALUES (287, '030401');
INSERT INTO public.ubigeo (district_id, code) VALUES (288, '030402');
INSERT INTO public.ubigeo (district_id, code) VALUES (289, '030403');
INSERT INTO public.ubigeo (district_id, code) VALUES (290, '030404');
INSERT INTO public.ubigeo (district_id, code) VALUES (291, '030405');
INSERT INTO public.ubigeo (district_id, code) VALUES (292, '030406');
INSERT INTO public.ubigeo (district_id, code) VALUES (293, '030407');
INSERT INTO public.ubigeo (district_id, code) VALUES (294, '030408');
INSERT INTO public.ubigeo (district_id, code) VALUES (295, '030409');
INSERT INTO public.ubigeo (district_id, code) VALUES (296, '030410');
INSERT INTO public.ubigeo (district_id, code) VALUES (297, '030411');
INSERT INTO public.ubigeo (district_id, code) VALUES (298, '030412');
INSERT INTO public.ubigeo (district_id, code) VALUES (299, '030413');
INSERT INTO public.ubigeo (district_id, code) VALUES (300, '030414');
INSERT INTO public.ubigeo (district_id, code) VALUES (301, '030415');
INSERT INTO public.ubigeo (district_id, code) VALUES (302, '030416');
INSERT INTO public.ubigeo (district_id, code) VALUES (303, '030417');
INSERT INTO public.ubigeo (district_id, code) VALUES (304, '030501');
INSERT INTO public.ubigeo (district_id, code) VALUES (305, '030502');
INSERT INTO public.ubigeo (district_id, code) VALUES (306, '030503');
INSERT INTO public.ubigeo (district_id, code) VALUES (307, '030504');
INSERT INTO public.ubigeo (district_id, code) VALUES (308, '030505');
INSERT INTO public.ubigeo (district_id, code) VALUES (309, '030506');
INSERT INTO public.ubigeo (district_id, code) VALUES (310, '030601');
INSERT INTO public.ubigeo (district_id, code) VALUES (311, '030602');
INSERT INTO public.ubigeo (district_id, code) VALUES (312, '030603');
INSERT INTO public.ubigeo (district_id, code) VALUES (313, '030604');
INSERT INTO public.ubigeo (district_id, code) VALUES (314, '030605');
INSERT INTO public.ubigeo (district_id, code) VALUES (315, '030606');
INSERT INTO public.ubigeo (district_id, code) VALUES (316, '030607');
INSERT INTO public.ubigeo (district_id, code) VALUES (317, '030608');
INSERT INTO public.ubigeo (district_id, code) VALUES (318, '030609');
INSERT INTO public.ubigeo (district_id, code) VALUES (319, '030610');
INSERT INTO public.ubigeo (district_id, code) VALUES (320, '030611');
INSERT INTO public.ubigeo (district_id, code) VALUES (321, '030701');
INSERT INTO public.ubigeo (district_id, code) VALUES (322, '030702');
INSERT INTO public.ubigeo (district_id, code) VALUES (323, '030703');
INSERT INTO public.ubigeo (district_id, code) VALUES (324, '030704');
INSERT INTO public.ubigeo (district_id, code) VALUES (325, '030705');
INSERT INTO public.ubigeo (district_id, code) VALUES (326, '030706');
INSERT INTO public.ubigeo (district_id, code) VALUES (327, '030707');
INSERT INTO public.ubigeo (district_id, code) VALUES (328, '030708');
INSERT INTO public.ubigeo (district_id, code) VALUES (329, '030709');
INSERT INTO public.ubigeo (district_id, code) VALUES (330, '030710');
INSERT INTO public.ubigeo (district_id, code) VALUES (331, '030711');
INSERT INTO public.ubigeo (district_id, code) VALUES (332, '030712');
INSERT INTO public.ubigeo (district_id, code) VALUES (333, '030713');
INSERT INTO public.ubigeo (district_id, code) VALUES (334, '030714');
INSERT INTO public.ubigeo (district_id, code) VALUES (335, '040101');
INSERT INTO public.ubigeo (district_id, code) VALUES (336, '040102');
INSERT INTO public.ubigeo (district_id, code) VALUES (337, '040103');
INSERT INTO public.ubigeo (district_id, code) VALUES (338, '040104');
INSERT INTO public.ubigeo (district_id, code) VALUES (339, '040105');
INSERT INTO public.ubigeo (district_id, code) VALUES (340, '040106');
INSERT INTO public.ubigeo (district_id, code) VALUES (341, '040107');
INSERT INTO public.ubigeo (district_id, code) VALUES (342, '040108');
INSERT INTO public.ubigeo (district_id, code) VALUES (343, '040109');
INSERT INTO public.ubigeo (district_id, code) VALUES (344, '040110');
INSERT INTO public.ubigeo (district_id, code) VALUES (345, '040111');
INSERT INTO public.ubigeo (district_id, code) VALUES (346, '040112');
INSERT INTO public.ubigeo (district_id, code) VALUES (347, '040113');
INSERT INTO public.ubigeo (district_id, code) VALUES (348, '040114');
INSERT INTO public.ubigeo (district_id, code) VALUES (349, '040115');
INSERT INTO public.ubigeo (district_id, code) VALUES (350, '040116');
INSERT INTO public.ubigeo (district_id, code) VALUES (351, '040117');
INSERT INTO public.ubigeo (district_id, code) VALUES (352, '040118');
INSERT INTO public.ubigeo (district_id, code) VALUES (353, '040119');
INSERT INTO public.ubigeo (district_id, code) VALUES (354, '040120');
INSERT INTO public.ubigeo (district_id, code) VALUES (355, '040121');
INSERT INTO public.ubigeo (district_id, code) VALUES (356, '040122');
INSERT INTO public.ubigeo (district_id, code) VALUES (357, '040123');
INSERT INTO public.ubigeo (district_id, code) VALUES (358, '040124');
INSERT INTO public.ubigeo (district_id, code) VALUES (359, '040125');
INSERT INTO public.ubigeo (district_id, code) VALUES (360, '040126');
INSERT INTO public.ubigeo (district_id, code) VALUES (361, '040127');
INSERT INTO public.ubigeo (district_id, code) VALUES (362, '040128');
INSERT INTO public.ubigeo (district_id, code) VALUES (363, '040129');
INSERT INTO public.ubigeo (district_id, code) VALUES (364, '040201');
INSERT INTO public.ubigeo (district_id, code) VALUES (365, '040202');
INSERT INTO public.ubigeo (district_id, code) VALUES (366, '040203');
INSERT INTO public.ubigeo (district_id, code) VALUES (367, '040204');
INSERT INTO public.ubigeo (district_id, code) VALUES (368, '040205');
INSERT INTO public.ubigeo (district_id, code) VALUES (369, '040206');
INSERT INTO public.ubigeo (district_id, code) VALUES (370, '040207');
INSERT INTO public.ubigeo (district_id, code) VALUES (371, '040208');
INSERT INTO public.ubigeo (district_id, code) VALUES (372, '040301');
INSERT INTO public.ubigeo (district_id, code) VALUES (373, '040302');
INSERT INTO public.ubigeo (district_id, code) VALUES (374, '040303');
INSERT INTO public.ubigeo (district_id, code) VALUES (375, '040304');
INSERT INTO public.ubigeo (district_id, code) VALUES (376, '040305');
INSERT INTO public.ubigeo (district_id, code) VALUES (377, '040306');
INSERT INTO public.ubigeo (district_id, code) VALUES (378, '040307');
INSERT INTO public.ubigeo (district_id, code) VALUES (379, '040308');
INSERT INTO public.ubigeo (district_id, code) VALUES (380, '040309');
INSERT INTO public.ubigeo (district_id, code) VALUES (381, '040310');
INSERT INTO public.ubigeo (district_id, code) VALUES (382, '040311');
INSERT INTO public.ubigeo (district_id, code) VALUES (383, '040312');
INSERT INTO public.ubigeo (district_id, code) VALUES (384, '040313');
INSERT INTO public.ubigeo (district_id, code) VALUES (385, '040401');
INSERT INTO public.ubigeo (district_id, code) VALUES (386, '040402');
INSERT INTO public.ubigeo (district_id, code) VALUES (387, '040403');
INSERT INTO public.ubigeo (district_id, code) VALUES (388, '040404');
INSERT INTO public.ubigeo (district_id, code) VALUES (389, '040405');
INSERT INTO public.ubigeo (district_id, code) VALUES (390, '040406');
INSERT INTO public.ubigeo (district_id, code) VALUES (391, '040407');
INSERT INTO public.ubigeo (district_id, code) VALUES (392, '040408');
INSERT INTO public.ubigeo (district_id, code) VALUES (393, '040409');
INSERT INTO public.ubigeo (district_id, code) VALUES (394, '040410');
INSERT INTO public.ubigeo (district_id, code) VALUES (395, '040411');
INSERT INTO public.ubigeo (district_id, code) VALUES (396, '040412');
INSERT INTO public.ubigeo (district_id, code) VALUES (397, '040413');
INSERT INTO public.ubigeo (district_id, code) VALUES (398, '040414');
INSERT INTO public.ubigeo (district_id, code) VALUES (399, '040501');
INSERT INTO public.ubigeo (district_id, code) VALUES (400, '040502');
INSERT INTO public.ubigeo (district_id, code) VALUES (401, '040503');
INSERT INTO public.ubigeo (district_id, code) VALUES (402, '040504');
INSERT INTO public.ubigeo (district_id, code) VALUES (403, '040505');
INSERT INTO public.ubigeo (district_id, code) VALUES (404, '040506');
INSERT INTO public.ubigeo (district_id, code) VALUES (405, '040507');
INSERT INTO public.ubigeo (district_id, code) VALUES (406, '040508');
INSERT INTO public.ubigeo (district_id, code) VALUES (407, '040509');
INSERT INTO public.ubigeo (district_id, code) VALUES (408, '040510');
INSERT INTO public.ubigeo (district_id, code) VALUES (409, '040511');
INSERT INTO public.ubigeo (district_id, code) VALUES (410, '040512');
INSERT INTO public.ubigeo (district_id, code) VALUES (411, '040513');
INSERT INTO public.ubigeo (district_id, code) VALUES (412, '040514');
INSERT INTO public.ubigeo (district_id, code) VALUES (413, '040515');
INSERT INTO public.ubigeo (district_id, code) VALUES (414, '040516');
INSERT INTO public.ubigeo (district_id, code) VALUES (415, '040517');
INSERT INTO public.ubigeo (district_id, code) VALUES (416, '040518');
INSERT INTO public.ubigeo (district_id, code) VALUES (417, '040519');
INSERT INTO public.ubigeo (district_id, code) VALUES (418, '040520');
INSERT INTO public.ubigeo (district_id, code) VALUES (419, '040601');
INSERT INTO public.ubigeo (district_id, code) VALUES (420, '040602');
INSERT INTO public.ubigeo (district_id, code) VALUES (421, '040603');
INSERT INTO public.ubigeo (district_id, code) VALUES (422, '040604');
INSERT INTO public.ubigeo (district_id, code) VALUES (423, '040605');
INSERT INTO public.ubigeo (district_id, code) VALUES (424, '040606');
INSERT INTO public.ubigeo (district_id, code) VALUES (425, '040607');
INSERT INTO public.ubigeo (district_id, code) VALUES (426, '040608');
INSERT INTO public.ubigeo (district_id, code) VALUES (427, '040701');
INSERT INTO public.ubigeo (district_id, code) VALUES (428, '040702');
INSERT INTO public.ubigeo (district_id, code) VALUES (429, '040703');
INSERT INTO public.ubigeo (district_id, code) VALUES (430, '040704');
INSERT INTO public.ubigeo (district_id, code) VALUES (431, '040705');
INSERT INTO public.ubigeo (district_id, code) VALUES (432, '040706');
INSERT INTO public.ubigeo (district_id, code) VALUES (433, '040801');
INSERT INTO public.ubigeo (district_id, code) VALUES (434, '040802');
INSERT INTO public.ubigeo (district_id, code) VALUES (435, '040803');
INSERT INTO public.ubigeo (district_id, code) VALUES (436, '040804');
INSERT INTO public.ubigeo (district_id, code) VALUES (437, '040805');
INSERT INTO public.ubigeo (district_id, code) VALUES (438, '040806');
INSERT INTO public.ubigeo (district_id, code) VALUES (439, '040807');
INSERT INTO public.ubigeo (district_id, code) VALUES (440, '040808');
INSERT INTO public.ubigeo (district_id, code) VALUES (441, '040809');
INSERT INTO public.ubigeo (district_id, code) VALUES (442, '040810');
INSERT INTO public.ubigeo (district_id, code) VALUES (443, '040811');
INSERT INTO public.ubigeo (district_id, code) VALUES (444, '050101');
INSERT INTO public.ubigeo (district_id, code) VALUES (445, '050102');
INSERT INTO public.ubigeo (district_id, code) VALUES (446, '050103');
INSERT INTO public.ubigeo (district_id, code) VALUES (447, '050104');
INSERT INTO public.ubigeo (district_id, code) VALUES (448, '050105');
INSERT INTO public.ubigeo (district_id, code) VALUES (449, '050106');
INSERT INTO public.ubigeo (district_id, code) VALUES (450, '050107');
INSERT INTO public.ubigeo (district_id, code) VALUES (451, '050108');
INSERT INTO public.ubigeo (district_id, code) VALUES (452, '050109');
INSERT INTO public.ubigeo (district_id, code) VALUES (453, '050110');
INSERT INTO public.ubigeo (district_id, code) VALUES (454, '050111');
INSERT INTO public.ubigeo (district_id, code) VALUES (455, '050112');
INSERT INTO public.ubigeo (district_id, code) VALUES (456, '050113');
INSERT INTO public.ubigeo (district_id, code) VALUES (457, '050114');
INSERT INTO public.ubigeo (district_id, code) VALUES (458, '050115');
INSERT INTO public.ubigeo (district_id, code) VALUES (459, '050116');
INSERT INTO public.ubigeo (district_id, code) VALUES (460, '050201');
INSERT INTO public.ubigeo (district_id, code) VALUES (461, '050202');
INSERT INTO public.ubigeo (district_id, code) VALUES (462, '050203');
INSERT INTO public.ubigeo (district_id, code) VALUES (463, '050204');
INSERT INTO public.ubigeo (district_id, code) VALUES (464, '050205');
INSERT INTO public.ubigeo (district_id, code) VALUES (465, '050206');
INSERT INTO public.ubigeo (district_id, code) VALUES (466, '050301');
INSERT INTO public.ubigeo (district_id, code) VALUES (467, '050302');
INSERT INTO public.ubigeo (district_id, code) VALUES (468, '050303');
INSERT INTO public.ubigeo (district_id, code) VALUES (469, '050304');
INSERT INTO public.ubigeo (district_id, code) VALUES (470, '050401');
INSERT INTO public.ubigeo (district_id, code) VALUES (471, '050402');
INSERT INTO public.ubigeo (district_id, code) VALUES (472, '050403');
INSERT INTO public.ubigeo (district_id, code) VALUES (473, '050404');
INSERT INTO public.ubigeo (district_id, code) VALUES (474, '050405');
INSERT INTO public.ubigeo (district_id, code) VALUES (475, '050406');
INSERT INTO public.ubigeo (district_id, code) VALUES (476, '050407');
INSERT INTO public.ubigeo (district_id, code) VALUES (477, '050408');
INSERT INTO public.ubigeo (district_id, code) VALUES (478, '050409');
INSERT INTO public.ubigeo (district_id, code) VALUES (479, '050410');
INSERT INTO public.ubigeo (district_id, code) VALUES (480, '050411');
INSERT INTO public.ubigeo (district_id, code) VALUES (481, '050412');
INSERT INTO public.ubigeo (district_id, code) VALUES (482, '050501');
INSERT INTO public.ubigeo (district_id, code) VALUES (483, '050502');
INSERT INTO public.ubigeo (district_id, code) VALUES (484, '050503');
INSERT INTO public.ubigeo (district_id, code) VALUES (485, '050504');
INSERT INTO public.ubigeo (district_id, code) VALUES (486, '050505');
INSERT INTO public.ubigeo (district_id, code) VALUES (487, '050506');
INSERT INTO public.ubigeo (district_id, code) VALUES (488, '050507');
INSERT INTO public.ubigeo (district_id, code) VALUES (489, '050508');
INSERT INTO public.ubigeo (district_id, code) VALUES (490, '050509');
INSERT INTO public.ubigeo (district_id, code) VALUES (491, '050510');
INSERT INTO public.ubigeo (district_id, code) VALUES (492, '050511');
INSERT INTO public.ubigeo (district_id, code) VALUES (493, '050601');
INSERT INTO public.ubigeo (district_id, code) VALUES (494, '050602');
INSERT INTO public.ubigeo (district_id, code) VALUES (495, '050603');
INSERT INTO public.ubigeo (district_id, code) VALUES (496, '050604');
INSERT INTO public.ubigeo (district_id, code) VALUES (497, '050605');
INSERT INTO public.ubigeo (district_id, code) VALUES (498, '050606');
INSERT INTO public.ubigeo (district_id, code) VALUES (499, '050607');
INSERT INTO public.ubigeo (district_id, code) VALUES (500, '050608');
INSERT INTO public.ubigeo (district_id, code) VALUES (501, '050609');
INSERT INTO public.ubigeo (district_id, code) VALUES (502, '050610');
INSERT INTO public.ubigeo (district_id, code) VALUES (503, '050611');
INSERT INTO public.ubigeo (district_id, code) VALUES (504, '050612');
INSERT INTO public.ubigeo (district_id, code) VALUES (505, '050613');
INSERT INTO public.ubigeo (district_id, code) VALUES (506, '050614');
INSERT INTO public.ubigeo (district_id, code) VALUES (507, '050615');
INSERT INTO public.ubigeo (district_id, code) VALUES (508, '050616');
INSERT INTO public.ubigeo (district_id, code) VALUES (509, '050617');
INSERT INTO public.ubigeo (district_id, code) VALUES (510, '050618');
INSERT INTO public.ubigeo (district_id, code) VALUES (511, '050619');
INSERT INTO public.ubigeo (district_id, code) VALUES (512, '050620');
INSERT INTO public.ubigeo (district_id, code) VALUES (513, '050621');
INSERT INTO public.ubigeo (district_id, code) VALUES (514, '050701');
INSERT INTO public.ubigeo (district_id, code) VALUES (515, '050702');
INSERT INTO public.ubigeo (district_id, code) VALUES (516, '050703');
INSERT INTO public.ubigeo (district_id, code) VALUES (517, '050704');
INSERT INTO public.ubigeo (district_id, code) VALUES (518, '050705');
INSERT INTO public.ubigeo (district_id, code) VALUES (519, '050706');
INSERT INTO public.ubigeo (district_id, code) VALUES (520, '050707');
INSERT INTO public.ubigeo (district_id, code) VALUES (521, '050708');
INSERT INTO public.ubigeo (district_id, code) VALUES (522, '050801');
INSERT INTO public.ubigeo (district_id, code) VALUES (523, '050802');
INSERT INTO public.ubigeo (district_id, code) VALUES (524, '050803');
INSERT INTO public.ubigeo (district_id, code) VALUES (525, '050804');
INSERT INTO public.ubigeo (district_id, code) VALUES (526, '050805');
INSERT INTO public.ubigeo (district_id, code) VALUES (527, '050806');
INSERT INTO public.ubigeo (district_id, code) VALUES (528, '050807');
INSERT INTO public.ubigeo (district_id, code) VALUES (529, '050808');
INSERT INTO public.ubigeo (district_id, code) VALUES (530, '050809');
INSERT INTO public.ubigeo (district_id, code) VALUES (531, '050810');
INSERT INTO public.ubigeo (district_id, code) VALUES (532, '050901');
INSERT INTO public.ubigeo (district_id, code) VALUES (533, '050902');
INSERT INTO public.ubigeo (district_id, code) VALUES (534, '050903');
INSERT INTO public.ubigeo (district_id, code) VALUES (535, '050904');
INSERT INTO public.ubigeo (district_id, code) VALUES (536, '050905');
INSERT INTO public.ubigeo (district_id, code) VALUES (537, '050906');
INSERT INTO public.ubigeo (district_id, code) VALUES (538, '050907');
INSERT INTO public.ubigeo (district_id, code) VALUES (539, '050908');
INSERT INTO public.ubigeo (district_id, code) VALUES (540, '050909');
INSERT INTO public.ubigeo (district_id, code) VALUES (541, '050910');
INSERT INTO public.ubigeo (district_id, code) VALUES (542, '050911');
INSERT INTO public.ubigeo (district_id, code) VALUES (543, '051001');
INSERT INTO public.ubigeo (district_id, code) VALUES (544, '051002');
INSERT INTO public.ubigeo (district_id, code) VALUES (545, '051003');
INSERT INTO public.ubigeo (district_id, code) VALUES (546, '051004');
INSERT INTO public.ubigeo (district_id, code) VALUES (547, '051005');
INSERT INTO public.ubigeo (district_id, code) VALUES (548, '051006');
INSERT INTO public.ubigeo (district_id, code) VALUES (549, '051007');
INSERT INTO public.ubigeo (district_id, code) VALUES (550, '051008');
INSERT INTO public.ubigeo (district_id, code) VALUES (551, '051009');
INSERT INTO public.ubigeo (district_id, code) VALUES (552, '051010');
INSERT INTO public.ubigeo (district_id, code) VALUES (553, '051011');
INSERT INTO public.ubigeo (district_id, code) VALUES (554, '051012');
INSERT INTO public.ubigeo (district_id, code) VALUES (555, '051101');
INSERT INTO public.ubigeo (district_id, code) VALUES (556, '051102');
INSERT INTO public.ubigeo (district_id, code) VALUES (557, '051103');
INSERT INTO public.ubigeo (district_id, code) VALUES (558, '051104');
INSERT INTO public.ubigeo (district_id, code) VALUES (559, '051105');
INSERT INTO public.ubigeo (district_id, code) VALUES (560, '051106');
INSERT INTO public.ubigeo (district_id, code) VALUES (561, '051107');
INSERT INTO public.ubigeo (district_id, code) VALUES (562, '051108');
INSERT INTO public.ubigeo (district_id, code) VALUES (563, '060101');
INSERT INTO public.ubigeo (district_id, code) VALUES (564, '060102');
INSERT INTO public.ubigeo (district_id, code) VALUES (565, '060103');
INSERT INTO public.ubigeo (district_id, code) VALUES (566, '060104');
INSERT INTO public.ubigeo (district_id, code) VALUES (567, '060105');
INSERT INTO public.ubigeo (district_id, code) VALUES (568, '060106');
INSERT INTO public.ubigeo (district_id, code) VALUES (569, '060107');
INSERT INTO public.ubigeo (district_id, code) VALUES (570, '060108');
INSERT INTO public.ubigeo (district_id, code) VALUES (571, '060109');
INSERT INTO public.ubigeo (district_id, code) VALUES (572, '060110');
INSERT INTO public.ubigeo (district_id, code) VALUES (573, '060111');
INSERT INTO public.ubigeo (district_id, code) VALUES (574, '060112');
INSERT INTO public.ubigeo (district_id, code) VALUES (575, '060201');
INSERT INTO public.ubigeo (district_id, code) VALUES (576, '060202');
INSERT INTO public.ubigeo (district_id, code) VALUES (577, '060203');
INSERT INTO public.ubigeo (district_id, code) VALUES (578, '060204');
INSERT INTO public.ubigeo (district_id, code) VALUES (579, '060301');
INSERT INTO public.ubigeo (district_id, code) VALUES (580, '060302');
INSERT INTO public.ubigeo (district_id, code) VALUES (581, '060303');
INSERT INTO public.ubigeo (district_id, code) VALUES (582, '060304');
INSERT INTO public.ubigeo (district_id, code) VALUES (583, '060305');
INSERT INTO public.ubigeo (district_id, code) VALUES (584, '060306');
INSERT INTO public.ubigeo (district_id, code) VALUES (585, '060307');
INSERT INTO public.ubigeo (district_id, code) VALUES (586, '060308');
INSERT INTO public.ubigeo (district_id, code) VALUES (587, '060309');
INSERT INTO public.ubigeo (district_id, code) VALUES (588, '060310');
INSERT INTO public.ubigeo (district_id, code) VALUES (589, '060311');
INSERT INTO public.ubigeo (district_id, code) VALUES (590, '060312');
INSERT INTO public.ubigeo (district_id, code) VALUES (591, '060401');
INSERT INTO public.ubigeo (district_id, code) VALUES (592, '060402');
INSERT INTO public.ubigeo (district_id, code) VALUES (593, '060403');
INSERT INTO public.ubigeo (district_id, code) VALUES (594, '060404');
INSERT INTO public.ubigeo (district_id, code) VALUES (595, '060405');
INSERT INTO public.ubigeo (district_id, code) VALUES (596, '060406');
INSERT INTO public.ubigeo (district_id, code) VALUES (597, '060407');
INSERT INTO public.ubigeo (district_id, code) VALUES (598, '060408');
INSERT INTO public.ubigeo (district_id, code) VALUES (599, '060409');
INSERT INTO public.ubigeo (district_id, code) VALUES (600, '060410');
INSERT INTO public.ubigeo (district_id, code) VALUES (601, '060411');
INSERT INTO public.ubigeo (district_id, code) VALUES (602, '060412');
INSERT INTO public.ubigeo (district_id, code) VALUES (603, '060413');
INSERT INTO public.ubigeo (district_id, code) VALUES (604, '060414');
INSERT INTO public.ubigeo (district_id, code) VALUES (605, '060415');
INSERT INTO public.ubigeo (district_id, code) VALUES (606, '060416');
INSERT INTO public.ubigeo (district_id, code) VALUES (607, '060417');
INSERT INTO public.ubigeo (district_id, code) VALUES (608, '060418');
INSERT INTO public.ubigeo (district_id, code) VALUES (609, '060419');
INSERT INTO public.ubigeo (district_id, code) VALUES (610, '060501');
INSERT INTO public.ubigeo (district_id, code) VALUES (611, '060502');
INSERT INTO public.ubigeo (district_id, code) VALUES (612, '060503');
INSERT INTO public.ubigeo (district_id, code) VALUES (613, '060504');
INSERT INTO public.ubigeo (district_id, code) VALUES (614, '060505');
INSERT INTO public.ubigeo (district_id, code) VALUES (615, '060506');
INSERT INTO public.ubigeo (district_id, code) VALUES (616, '060507');
INSERT INTO public.ubigeo (district_id, code) VALUES (617, '060508');
INSERT INTO public.ubigeo (district_id, code) VALUES (618, '060601');
INSERT INTO public.ubigeo (district_id, code) VALUES (619, '060602');
INSERT INTO public.ubigeo (district_id, code) VALUES (620, '060603');
INSERT INTO public.ubigeo (district_id, code) VALUES (621, '060604');
INSERT INTO public.ubigeo (district_id, code) VALUES (622, '060605');
INSERT INTO public.ubigeo (district_id, code) VALUES (623, '060606');
INSERT INTO public.ubigeo (district_id, code) VALUES (624, '060607');
INSERT INTO public.ubigeo (district_id, code) VALUES (625, '060608');
INSERT INTO public.ubigeo (district_id, code) VALUES (626, '060609');
INSERT INTO public.ubigeo (district_id, code) VALUES (627, '060610');
INSERT INTO public.ubigeo (district_id, code) VALUES (628, '060611');
INSERT INTO public.ubigeo (district_id, code) VALUES (629, '060612');
INSERT INTO public.ubigeo (district_id, code) VALUES (630, '060613');
INSERT INTO public.ubigeo (district_id, code) VALUES (631, '060614');
INSERT INTO public.ubigeo (district_id, code) VALUES (632, '060615');
INSERT INTO public.ubigeo (district_id, code) VALUES (633, '060701');
INSERT INTO public.ubigeo (district_id, code) VALUES (634, '060702');
INSERT INTO public.ubigeo (district_id, code) VALUES (635, '060703');
INSERT INTO public.ubigeo (district_id, code) VALUES (636, '060801');
INSERT INTO public.ubigeo (district_id, code) VALUES (637, '060802');
INSERT INTO public.ubigeo (district_id, code) VALUES (638, '060803');
INSERT INTO public.ubigeo (district_id, code) VALUES (639, '060804');
INSERT INTO public.ubigeo (district_id, code) VALUES (640, '060805');
INSERT INTO public.ubigeo (district_id, code) VALUES (641, '060806');
INSERT INTO public.ubigeo (district_id, code) VALUES (642, '060807');
INSERT INTO public.ubigeo (district_id, code) VALUES (643, '060808');
INSERT INTO public.ubigeo (district_id, code) VALUES (644, '060809');
INSERT INTO public.ubigeo (district_id, code) VALUES (645, '060810');
INSERT INTO public.ubigeo (district_id, code) VALUES (646, '060811');
INSERT INTO public.ubigeo (district_id, code) VALUES (647, '060812');
INSERT INTO public.ubigeo (district_id, code) VALUES (648, '060901');
INSERT INTO public.ubigeo (district_id, code) VALUES (649, '060902');
INSERT INTO public.ubigeo (district_id, code) VALUES (650, '060903');
INSERT INTO public.ubigeo (district_id, code) VALUES (651, '060904');
INSERT INTO public.ubigeo (district_id, code) VALUES (652, '060905');
INSERT INTO public.ubigeo (district_id, code) VALUES (653, '060906');
INSERT INTO public.ubigeo (district_id, code) VALUES (654, '060907');
INSERT INTO public.ubigeo (district_id, code) VALUES (655, '061001');
INSERT INTO public.ubigeo (district_id, code) VALUES (656, '061002');
INSERT INTO public.ubigeo (district_id, code) VALUES (657, '061003');
INSERT INTO public.ubigeo (district_id, code) VALUES (658, '061004');
INSERT INTO public.ubigeo (district_id, code) VALUES (659, '061005');
INSERT INTO public.ubigeo (district_id, code) VALUES (660, '061006');
INSERT INTO public.ubigeo (district_id, code) VALUES (661, '061007');
INSERT INTO public.ubigeo (district_id, code) VALUES (662, '061101');
INSERT INTO public.ubigeo (district_id, code) VALUES (663, '061102');
INSERT INTO public.ubigeo (district_id, code) VALUES (664, '061103');
INSERT INTO public.ubigeo (district_id, code) VALUES (665, '061104');
INSERT INTO public.ubigeo (district_id, code) VALUES (666, '061105');
INSERT INTO public.ubigeo (district_id, code) VALUES (667, '061106');
INSERT INTO public.ubigeo (district_id, code) VALUES (668, '061107');
INSERT INTO public.ubigeo (district_id, code) VALUES (669, '061108');
INSERT INTO public.ubigeo (district_id, code) VALUES (670, '061109');
INSERT INTO public.ubigeo (district_id, code) VALUES (671, '061110');
INSERT INTO public.ubigeo (district_id, code) VALUES (672, '061111');
INSERT INTO public.ubigeo (district_id, code) VALUES (673, '061112');
INSERT INTO public.ubigeo (district_id, code) VALUES (674, '061113');
INSERT INTO public.ubigeo (district_id, code) VALUES (675, '061201');
INSERT INTO public.ubigeo (district_id, code) VALUES (676, '061202');
INSERT INTO public.ubigeo (district_id, code) VALUES (677, '061203');
INSERT INTO public.ubigeo (district_id, code) VALUES (678, '061204');
INSERT INTO public.ubigeo (district_id, code) VALUES (679, '061301');
INSERT INTO public.ubigeo (district_id, code) VALUES (680, '061302');
INSERT INTO public.ubigeo (district_id, code) VALUES (681, '061303');
INSERT INTO public.ubigeo (district_id, code) VALUES (682, '061304');
INSERT INTO public.ubigeo (district_id, code) VALUES (683, '061305');
INSERT INTO public.ubigeo (district_id, code) VALUES (684, '061306');
INSERT INTO public.ubigeo (district_id, code) VALUES (685, '061307');
INSERT INTO public.ubigeo (district_id, code) VALUES (686, '061308');
INSERT INTO public.ubigeo (district_id, code) VALUES (687, '061309');
INSERT INTO public.ubigeo (district_id, code) VALUES (688, '061310');
INSERT INTO public.ubigeo (district_id, code) VALUES (689, '061311');
INSERT INTO public.ubigeo (district_id, code) VALUES (690, '070101');
INSERT INTO public.ubigeo (district_id, code) VALUES (691, '070102');
INSERT INTO public.ubigeo (district_id, code) VALUES (692, '070103');
INSERT INTO public.ubigeo (district_id, code) VALUES (693, '070104');
INSERT INTO public.ubigeo (district_id, code) VALUES (694, '070105');
INSERT INTO public.ubigeo (district_id, code) VALUES (695, '070106');
INSERT INTO public.ubigeo (district_id, code) VALUES (696, '070107');
INSERT INTO public.ubigeo (district_id, code) VALUES (697, '080101');
INSERT INTO public.ubigeo (district_id, code) VALUES (698, '080102');
INSERT INTO public.ubigeo (district_id, code) VALUES (699, '080103');
INSERT INTO public.ubigeo (district_id, code) VALUES (700, '080104');
INSERT INTO public.ubigeo (district_id, code) VALUES (701, '080105');
INSERT INTO public.ubigeo (district_id, code) VALUES (702, '080106');
INSERT INTO public.ubigeo (district_id, code) VALUES (703, '080107');
INSERT INTO public.ubigeo (district_id, code) VALUES (704, '080108');
INSERT INTO public.ubigeo (district_id, code) VALUES (705, '080201');
INSERT INTO public.ubigeo (district_id, code) VALUES (706, '080202');
INSERT INTO public.ubigeo (district_id, code) VALUES (707, '080203');
INSERT INTO public.ubigeo (district_id, code) VALUES (708, '080204');
INSERT INTO public.ubigeo (district_id, code) VALUES (709, '080205');
INSERT INTO public.ubigeo (district_id, code) VALUES (710, '080206');
INSERT INTO public.ubigeo (district_id, code) VALUES (711, '080207');
INSERT INTO public.ubigeo (district_id, code) VALUES (712, '080301');
INSERT INTO public.ubigeo (district_id, code) VALUES (713, '080302');
INSERT INTO public.ubigeo (district_id, code) VALUES (714, '080303');
INSERT INTO public.ubigeo (district_id, code) VALUES (715, '080304');
INSERT INTO public.ubigeo (district_id, code) VALUES (716, '080305');
INSERT INTO public.ubigeo (district_id, code) VALUES (717, '080306');
INSERT INTO public.ubigeo (district_id, code) VALUES (718, '080307');
INSERT INTO public.ubigeo (district_id, code) VALUES (719, '080308');
INSERT INTO public.ubigeo (district_id, code) VALUES (720, '080309');
INSERT INTO public.ubigeo (district_id, code) VALUES (721, '080401');
INSERT INTO public.ubigeo (district_id, code) VALUES (722, '080402');
INSERT INTO public.ubigeo (district_id, code) VALUES (723, '080403');
INSERT INTO public.ubigeo (district_id, code) VALUES (724, '080404');
INSERT INTO public.ubigeo (district_id, code) VALUES (725, '080405');
INSERT INTO public.ubigeo (district_id, code) VALUES (726, '080406');
INSERT INTO public.ubigeo (district_id, code) VALUES (727, '080407');
INSERT INTO public.ubigeo (district_id, code) VALUES (728, '080408');
INSERT INTO public.ubigeo (district_id, code) VALUES (729, '080501');
INSERT INTO public.ubigeo (district_id, code) VALUES (730, '080502');
INSERT INTO public.ubigeo (district_id, code) VALUES (731, '080503');
INSERT INTO public.ubigeo (district_id, code) VALUES (732, '080504');
INSERT INTO public.ubigeo (district_id, code) VALUES (733, '080505');
INSERT INTO public.ubigeo (district_id, code) VALUES (734, '080506');
INSERT INTO public.ubigeo (district_id, code) VALUES (735, '080507');
INSERT INTO public.ubigeo (district_id, code) VALUES (736, '080508');
INSERT INTO public.ubigeo (district_id, code) VALUES (737, '080601');
INSERT INTO public.ubigeo (district_id, code) VALUES (738, '080602');
INSERT INTO public.ubigeo (district_id, code) VALUES (739, '080603');
INSERT INTO public.ubigeo (district_id, code) VALUES (740, '080604');
INSERT INTO public.ubigeo (district_id, code) VALUES (741, '080605');
INSERT INTO public.ubigeo (district_id, code) VALUES (742, '080606');
INSERT INTO public.ubigeo (district_id, code) VALUES (743, '080607');
INSERT INTO public.ubigeo (district_id, code) VALUES (744, '080608');
INSERT INTO public.ubigeo (district_id, code) VALUES (745, '080701');
INSERT INTO public.ubigeo (district_id, code) VALUES (746, '080702');
INSERT INTO public.ubigeo (district_id, code) VALUES (747, '080703');
INSERT INTO public.ubigeo (district_id, code) VALUES (748, '080704');
INSERT INTO public.ubigeo (district_id, code) VALUES (749, '080705');
INSERT INTO public.ubigeo (district_id, code) VALUES (750, '080706');
INSERT INTO public.ubigeo (district_id, code) VALUES (751, '080707');
INSERT INTO public.ubigeo (district_id, code) VALUES (752, '080708');
INSERT INTO public.ubigeo (district_id, code) VALUES (753, '080801');
INSERT INTO public.ubigeo (district_id, code) VALUES (754, '080802');
INSERT INTO public.ubigeo (district_id, code) VALUES (755, '080803');
INSERT INTO public.ubigeo (district_id, code) VALUES (756, '080804');
INSERT INTO public.ubigeo (district_id, code) VALUES (757, '080805');
INSERT INTO public.ubigeo (district_id, code) VALUES (758, '080806');
INSERT INTO public.ubigeo (district_id, code) VALUES (759, '080807');
INSERT INTO public.ubigeo (district_id, code) VALUES (760, '080808');
INSERT INTO public.ubigeo (district_id, code) VALUES (761, '080901');
INSERT INTO public.ubigeo (district_id, code) VALUES (762, '080902');
INSERT INTO public.ubigeo (district_id, code) VALUES (763, '080903');
INSERT INTO public.ubigeo (district_id, code) VALUES (764, '080904');
INSERT INTO public.ubigeo (district_id, code) VALUES (765, '080905');
INSERT INTO public.ubigeo (district_id, code) VALUES (766, '080906');
INSERT INTO public.ubigeo (district_id, code) VALUES (767, '080907');
INSERT INTO public.ubigeo (district_id, code) VALUES (768, '080908');
INSERT INTO public.ubigeo (district_id, code) VALUES (769, '080909');
INSERT INTO public.ubigeo (district_id, code) VALUES (770, '080910');
INSERT INTO public.ubigeo (district_id, code) VALUES (771, '080911');
INSERT INTO public.ubigeo (district_id, code) VALUES (772, '080912');
INSERT INTO public.ubigeo (district_id, code) VALUES (773, '080913');
INSERT INTO public.ubigeo (district_id, code) VALUES (774, '080914');
INSERT INTO public.ubigeo (district_id, code) VALUES (775, '081001');
INSERT INTO public.ubigeo (district_id, code) VALUES (776, '081002');
INSERT INTO public.ubigeo (district_id, code) VALUES (777, '081003');
INSERT INTO public.ubigeo (district_id, code) VALUES (778, '081004');
INSERT INTO public.ubigeo (district_id, code) VALUES (779, '081005');
INSERT INTO public.ubigeo (district_id, code) VALUES (780, '081006');
INSERT INTO public.ubigeo (district_id, code) VALUES (781, '081007');
INSERT INTO public.ubigeo (district_id, code) VALUES (782, '081008');
INSERT INTO public.ubigeo (district_id, code) VALUES (783, '081009');
INSERT INTO public.ubigeo (district_id, code) VALUES (784, '081101');
INSERT INTO public.ubigeo (district_id, code) VALUES (785, '081102');
INSERT INTO public.ubigeo (district_id, code) VALUES (786, '081103');
INSERT INTO public.ubigeo (district_id, code) VALUES (787, '081104');
INSERT INTO public.ubigeo (district_id, code) VALUES (788, '081105');
INSERT INTO public.ubigeo (district_id, code) VALUES (789, '081106');
INSERT INTO public.ubigeo (district_id, code) VALUES (790, '081201');
INSERT INTO public.ubigeo (district_id, code) VALUES (791, '081202');
INSERT INTO public.ubigeo (district_id, code) VALUES (792, '081203');
INSERT INTO public.ubigeo (district_id, code) VALUES (793, '081204');
INSERT INTO public.ubigeo (district_id, code) VALUES (794, '081205');
INSERT INTO public.ubigeo (district_id, code) VALUES (795, '081206');
INSERT INTO public.ubigeo (district_id, code) VALUES (796, '081207');
INSERT INTO public.ubigeo (district_id, code) VALUES (797, '081208');
INSERT INTO public.ubigeo (district_id, code) VALUES (798, '081209');
INSERT INTO public.ubigeo (district_id, code) VALUES (799, '081210');
INSERT INTO public.ubigeo (district_id, code) VALUES (800, '081211');
INSERT INTO public.ubigeo (district_id, code) VALUES (801, '081212');
INSERT INTO public.ubigeo (district_id, code) VALUES (802, '081301');
INSERT INTO public.ubigeo (district_id, code) VALUES (803, '081302');
INSERT INTO public.ubigeo (district_id, code) VALUES (804, '081303');
INSERT INTO public.ubigeo (district_id, code) VALUES (805, '081304');
INSERT INTO public.ubigeo (district_id, code) VALUES (806, '081305');
INSERT INTO public.ubigeo (district_id, code) VALUES (807, '081306');
INSERT INTO public.ubigeo (district_id, code) VALUES (808, '081307');
INSERT INTO public.ubigeo (district_id, code) VALUES (809, '090101');
INSERT INTO public.ubigeo (district_id, code) VALUES (810, '090102');
INSERT INTO public.ubigeo (district_id, code) VALUES (811, '090103');
INSERT INTO public.ubigeo (district_id, code) VALUES (812, '090104');
INSERT INTO public.ubigeo (district_id, code) VALUES (813, '090105');
INSERT INTO public.ubigeo (district_id, code) VALUES (814, '090106');
INSERT INTO public.ubigeo (district_id, code) VALUES (815, '090107');
INSERT INTO public.ubigeo (district_id, code) VALUES (816, '090108');
INSERT INTO public.ubigeo (district_id, code) VALUES (817, '090109');
INSERT INTO public.ubigeo (district_id, code) VALUES (818, '090110');
INSERT INTO public.ubigeo (district_id, code) VALUES (819, '090111');
INSERT INTO public.ubigeo (district_id, code) VALUES (820, '090112');
INSERT INTO public.ubigeo (district_id, code) VALUES (821, '090113');
INSERT INTO public.ubigeo (district_id, code) VALUES (822, '090114');
INSERT INTO public.ubigeo (district_id, code) VALUES (823, '090115');
INSERT INTO public.ubigeo (district_id, code) VALUES (824, '090116');
INSERT INTO public.ubigeo (district_id, code) VALUES (825, '090117');
INSERT INTO public.ubigeo (district_id, code) VALUES (826, '090118');
INSERT INTO public.ubigeo (district_id, code) VALUES (827, '090119');
INSERT INTO public.ubigeo (district_id, code) VALUES (828, '090201');
INSERT INTO public.ubigeo (district_id, code) VALUES (829, '090202');
INSERT INTO public.ubigeo (district_id, code) VALUES (830, '090203');
INSERT INTO public.ubigeo (district_id, code) VALUES (831, '090204');
INSERT INTO public.ubigeo (district_id, code) VALUES (832, '090205');
INSERT INTO public.ubigeo (district_id, code) VALUES (833, '090206');
INSERT INTO public.ubigeo (district_id, code) VALUES (834, '090207');
INSERT INTO public.ubigeo (district_id, code) VALUES (835, '090208');
INSERT INTO public.ubigeo (district_id, code) VALUES (836, '090301');
INSERT INTO public.ubigeo (district_id, code) VALUES (837, '090302');
INSERT INTO public.ubigeo (district_id, code) VALUES (838, '090303');
INSERT INTO public.ubigeo (district_id, code) VALUES (839, '090304');
INSERT INTO public.ubigeo (district_id, code) VALUES (840, '090305');
INSERT INTO public.ubigeo (district_id, code) VALUES (841, '090306');
INSERT INTO public.ubigeo (district_id, code) VALUES (842, '090307');
INSERT INTO public.ubigeo (district_id, code) VALUES (843, '090308');
INSERT INTO public.ubigeo (district_id, code) VALUES (844, '090309');
INSERT INTO public.ubigeo (district_id, code) VALUES (845, '090310');
INSERT INTO public.ubigeo (district_id, code) VALUES (846, '090311');
INSERT INTO public.ubigeo (district_id, code) VALUES (847, '090312');
INSERT INTO public.ubigeo (district_id, code) VALUES (848, '090401');
INSERT INTO public.ubigeo (district_id, code) VALUES (849, '090402');
INSERT INTO public.ubigeo (district_id, code) VALUES (850, '090403');
INSERT INTO public.ubigeo (district_id, code) VALUES (851, '090404');
INSERT INTO public.ubigeo (district_id, code) VALUES (852, '090405');
INSERT INTO public.ubigeo (district_id, code) VALUES (853, '090406');
INSERT INTO public.ubigeo (district_id, code) VALUES (854, '090407');
INSERT INTO public.ubigeo (district_id, code) VALUES (855, '090408');
INSERT INTO public.ubigeo (district_id, code) VALUES (856, '090409');
INSERT INTO public.ubigeo (district_id, code) VALUES (857, '090410');
INSERT INTO public.ubigeo (district_id, code) VALUES (858, '090411');
INSERT INTO public.ubigeo (district_id, code) VALUES (859, '090412');
INSERT INTO public.ubigeo (district_id, code) VALUES (860, '090413');
INSERT INTO public.ubigeo (district_id, code) VALUES (861, '090501');
INSERT INTO public.ubigeo (district_id, code) VALUES (862, '090502');
INSERT INTO public.ubigeo (district_id, code) VALUES (863, '090503');
INSERT INTO public.ubigeo (district_id, code) VALUES (864, '090504');
INSERT INTO public.ubigeo (district_id, code) VALUES (865, '090505');
INSERT INTO public.ubigeo (district_id, code) VALUES (866, '090506');
INSERT INTO public.ubigeo (district_id, code) VALUES (867, '090507');
INSERT INTO public.ubigeo (district_id, code) VALUES (868, '090508');
INSERT INTO public.ubigeo (district_id, code) VALUES (869, '090509');
INSERT INTO public.ubigeo (district_id, code) VALUES (870, '090510');
INSERT INTO public.ubigeo (district_id, code) VALUES (871, '090511');
INSERT INTO public.ubigeo (district_id, code) VALUES (872, '090601');
INSERT INTO public.ubigeo (district_id, code) VALUES (873, '090602');
INSERT INTO public.ubigeo (district_id, code) VALUES (874, '090603');
INSERT INTO public.ubigeo (district_id, code) VALUES (875, '090604');
INSERT INTO public.ubigeo (district_id, code) VALUES (876, '090605');
INSERT INTO public.ubigeo (district_id, code) VALUES (877, '090606');
INSERT INTO public.ubigeo (district_id, code) VALUES (878, '090607');
INSERT INTO public.ubigeo (district_id, code) VALUES (879, '090608');
INSERT INTO public.ubigeo (district_id, code) VALUES (880, '090609');
INSERT INTO public.ubigeo (district_id, code) VALUES (881, '090610');
INSERT INTO public.ubigeo (district_id, code) VALUES (882, '090611');
INSERT INTO public.ubigeo (district_id, code) VALUES (883, '090612');
INSERT INTO public.ubigeo (district_id, code) VALUES (884, '090613');
INSERT INTO public.ubigeo (district_id, code) VALUES (885, '090614');
INSERT INTO public.ubigeo (district_id, code) VALUES (886, '090615');
INSERT INTO public.ubigeo (district_id, code) VALUES (887, '090616');
INSERT INTO public.ubigeo (district_id, code) VALUES (888, '090701');
INSERT INTO public.ubigeo (district_id, code) VALUES (889, '090702');
INSERT INTO public.ubigeo (district_id, code) VALUES (890, '090703');
INSERT INTO public.ubigeo (district_id, code) VALUES (891, '090704');
INSERT INTO public.ubigeo (district_id, code) VALUES (892, '090705');
INSERT INTO public.ubigeo (district_id, code) VALUES (893, '090706');
INSERT INTO public.ubigeo (district_id, code) VALUES (894, '090707');
INSERT INTO public.ubigeo (district_id, code) VALUES (895, '090709');
INSERT INTO public.ubigeo (district_id, code) VALUES (896, '090710');
INSERT INTO public.ubigeo (district_id, code) VALUES (897, '090711');
INSERT INTO public.ubigeo (district_id, code) VALUES (898, '090713');
INSERT INTO public.ubigeo (district_id, code) VALUES (899, '090714');
INSERT INTO public.ubigeo (district_id, code) VALUES (900, '090715');
INSERT INTO public.ubigeo (district_id, code) VALUES (901, '090716');
INSERT INTO public.ubigeo (district_id, code) VALUES (902, '090717');
INSERT INTO public.ubigeo (district_id, code) VALUES (903, '090718');
INSERT INTO public.ubigeo (district_id, code) VALUES (904, '090719');
INSERT INTO public.ubigeo (district_id, code) VALUES (905, '090720');
INSERT INTO public.ubigeo (district_id, code) VALUES (906, '090721');
INSERT INTO public.ubigeo (district_id, code) VALUES (907, '090722');
INSERT INTO public.ubigeo (district_id, code) VALUES (908, '090723');
INSERT INTO public.ubigeo (district_id, code) VALUES (909, '100101');
INSERT INTO public.ubigeo (district_id, code) VALUES (910, '100102');
INSERT INTO public.ubigeo (district_id, code) VALUES (911, '100103');
INSERT INTO public.ubigeo (district_id, code) VALUES (912, '100104');
INSERT INTO public.ubigeo (district_id, code) VALUES (913, '100105');
INSERT INTO public.ubigeo (district_id, code) VALUES (914, '100106');
INSERT INTO public.ubigeo (district_id, code) VALUES (915, '100107');
INSERT INTO public.ubigeo (district_id, code) VALUES (916, '100108');
INSERT INTO public.ubigeo (district_id, code) VALUES (917, '100109');
INSERT INTO public.ubigeo (district_id, code) VALUES (918, '100110');
INSERT INTO public.ubigeo (district_id, code) VALUES (919, '100111');
INSERT INTO public.ubigeo (district_id, code) VALUES (920, '100112');
INSERT INTO public.ubigeo (district_id, code) VALUES (921, '100113');
INSERT INTO public.ubigeo (district_id, code) VALUES (922, '100201');
INSERT INTO public.ubigeo (district_id, code) VALUES (923, '100202');
INSERT INTO public.ubigeo (district_id, code) VALUES (924, '100203');
INSERT INTO public.ubigeo (district_id, code) VALUES (925, '100204');
INSERT INTO public.ubigeo (district_id, code) VALUES (926, '100205');
INSERT INTO public.ubigeo (district_id, code) VALUES (927, '100206');
INSERT INTO public.ubigeo (district_id, code) VALUES (928, '100207');
INSERT INTO public.ubigeo (district_id, code) VALUES (929, '100208');
INSERT INTO public.ubigeo (district_id, code) VALUES (930, '100301');
INSERT INTO public.ubigeo (district_id, code) VALUES (931, '100307');
INSERT INTO public.ubigeo (district_id, code) VALUES (932, '100311');
INSERT INTO public.ubigeo (district_id, code) VALUES (933, '100313');
INSERT INTO public.ubigeo (district_id, code) VALUES (934, '100316');
INSERT INTO public.ubigeo (district_id, code) VALUES (935, '100317');
INSERT INTO public.ubigeo (district_id, code) VALUES (936, '100321');
INSERT INTO public.ubigeo (district_id, code) VALUES (937, '100322');
INSERT INTO public.ubigeo (district_id, code) VALUES (938, '100323');
INSERT INTO public.ubigeo (district_id, code) VALUES (939, '100401');
INSERT INTO public.ubigeo (district_id, code) VALUES (940, '100402');
INSERT INTO public.ubigeo (district_id, code) VALUES (941, '100403');
INSERT INTO public.ubigeo (district_id, code) VALUES (942, '100404');
INSERT INTO public.ubigeo (district_id, code) VALUES (943, '100501');
INSERT INTO public.ubigeo (district_id, code) VALUES (944, '100502');
INSERT INTO public.ubigeo (district_id, code) VALUES (945, '100503');
INSERT INTO public.ubigeo (district_id, code) VALUES (946, '100504');
INSERT INTO public.ubigeo (district_id, code) VALUES (947, '100505');
INSERT INTO public.ubigeo (district_id, code) VALUES (948, '100506');
INSERT INTO public.ubigeo (district_id, code) VALUES (949, '100507');
INSERT INTO public.ubigeo (district_id, code) VALUES (950, '100508');
INSERT INTO public.ubigeo (district_id, code) VALUES (951, '100509');
INSERT INTO public.ubigeo (district_id, code) VALUES (952, '100510');
INSERT INTO public.ubigeo (district_id, code) VALUES (953, '100511');
INSERT INTO public.ubigeo (district_id, code) VALUES (954, '100601');
INSERT INTO public.ubigeo (district_id, code) VALUES (955, '100602');
INSERT INTO public.ubigeo (district_id, code) VALUES (956, '100603');
INSERT INTO public.ubigeo (district_id, code) VALUES (957, '100604');
INSERT INTO public.ubigeo (district_id, code) VALUES (958, '100605');
INSERT INTO public.ubigeo (district_id, code) VALUES (959, '100606');
INSERT INTO public.ubigeo (district_id, code) VALUES (960, '100607');
INSERT INTO public.ubigeo (district_id, code) VALUES (961, '100608');
INSERT INTO public.ubigeo (district_id, code) VALUES (962, '100609');
INSERT INTO public.ubigeo (district_id, code) VALUES (963, '100610');
INSERT INTO public.ubigeo (district_id, code) VALUES (964, '100701');
INSERT INTO public.ubigeo (district_id, code) VALUES (965, '100702');
INSERT INTO public.ubigeo (district_id, code) VALUES (966, '100703');
INSERT INTO public.ubigeo (district_id, code) VALUES (967, '100704');
INSERT INTO public.ubigeo (district_id, code) VALUES (968, '100705');
INSERT INTO public.ubigeo (district_id, code) VALUES (969, '100801');
INSERT INTO public.ubigeo (district_id, code) VALUES (970, '100802');
INSERT INTO public.ubigeo (district_id, code) VALUES (971, '100803');
INSERT INTO public.ubigeo (district_id, code) VALUES (972, '100804');
INSERT INTO public.ubigeo (district_id, code) VALUES (973, '100901');
INSERT INTO public.ubigeo (district_id, code) VALUES (974, '100902');
INSERT INTO public.ubigeo (district_id, code) VALUES (975, '100903');
INSERT INTO public.ubigeo (district_id, code) VALUES (976, '100904');
INSERT INTO public.ubigeo (district_id, code) VALUES (977, '100905');
INSERT INTO public.ubigeo (district_id, code) VALUES (978, '101001');
INSERT INTO public.ubigeo (district_id, code) VALUES (979, '101002');
INSERT INTO public.ubigeo (district_id, code) VALUES (980, '101003');
INSERT INTO public.ubigeo (district_id, code) VALUES (981, '101004');
INSERT INTO public.ubigeo (district_id, code) VALUES (982, '101005');
INSERT INTO public.ubigeo (district_id, code) VALUES (983, '101006');
INSERT INTO public.ubigeo (district_id, code) VALUES (984, '101007');
INSERT INTO public.ubigeo (district_id, code) VALUES (985, '101101');
INSERT INTO public.ubigeo (district_id, code) VALUES (986, '101102');
INSERT INTO public.ubigeo (district_id, code) VALUES (987, '101103');
INSERT INTO public.ubigeo (district_id, code) VALUES (988, '101104');
INSERT INTO public.ubigeo (district_id, code) VALUES (989, '101105');
INSERT INTO public.ubigeo (district_id, code) VALUES (990, '101106');
INSERT INTO public.ubigeo (district_id, code) VALUES (991, '101107');
INSERT INTO public.ubigeo (district_id, code) VALUES (992, '101108');
INSERT INTO public.ubigeo (district_id, code) VALUES (993, '110101');
INSERT INTO public.ubigeo (district_id, code) VALUES (994, '110102');
INSERT INTO public.ubigeo (district_id, code) VALUES (995, '110103');
INSERT INTO public.ubigeo (district_id, code) VALUES (996, '110104');
INSERT INTO public.ubigeo (district_id, code) VALUES (997, '110105');
INSERT INTO public.ubigeo (district_id, code) VALUES (998, '110106');
INSERT INTO public.ubigeo (district_id, code) VALUES (999, '110107');
INSERT INTO public.ubigeo (district_id, code) VALUES (1000, '110108');
INSERT INTO public.ubigeo (district_id, code) VALUES (1001, '110109');
INSERT INTO public.ubigeo (district_id, code) VALUES (1002, '110110');
INSERT INTO public.ubigeo (district_id, code) VALUES (1003, '110111');
INSERT INTO public.ubigeo (district_id, code) VALUES (1004, '110112');
INSERT INTO public.ubigeo (district_id, code) VALUES (1005, '110113');
INSERT INTO public.ubigeo (district_id, code) VALUES (1006, '110114');
INSERT INTO public.ubigeo (district_id, code) VALUES (1007, '110201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1008, '110202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1009, '110203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1010, '110204');
INSERT INTO public.ubigeo (district_id, code) VALUES (1011, '110205');
INSERT INTO public.ubigeo (district_id, code) VALUES (1012, '110206');
INSERT INTO public.ubigeo (district_id, code) VALUES (1013, '110207');
INSERT INTO public.ubigeo (district_id, code) VALUES (1014, '110208');
INSERT INTO public.ubigeo (district_id, code) VALUES (1015, '110209');
INSERT INTO public.ubigeo (district_id, code) VALUES (1016, '110210');
INSERT INTO public.ubigeo (district_id, code) VALUES (1017, '110211');
INSERT INTO public.ubigeo (district_id, code) VALUES (1018, '110301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1019, '110302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1020, '110303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1021, '110304');
INSERT INTO public.ubigeo (district_id, code) VALUES (1022, '110305');
INSERT INTO public.ubigeo (district_id, code) VALUES (1023, '110401');
INSERT INTO public.ubigeo (district_id, code) VALUES (1024, '110402');
INSERT INTO public.ubigeo (district_id, code) VALUES (1025, '110403');
INSERT INTO public.ubigeo (district_id, code) VALUES (1026, '110404');
INSERT INTO public.ubigeo (district_id, code) VALUES (1027, '110405');
INSERT INTO public.ubigeo (district_id, code) VALUES (1028, '110501');
INSERT INTO public.ubigeo (district_id, code) VALUES (1029, '110502');
INSERT INTO public.ubigeo (district_id, code) VALUES (1030, '110503');
INSERT INTO public.ubigeo (district_id, code) VALUES (1031, '110504');
INSERT INTO public.ubigeo (district_id, code) VALUES (1032, '110505');
INSERT INTO public.ubigeo (district_id, code) VALUES (1033, '110506');
INSERT INTO public.ubigeo (district_id, code) VALUES (1034, '110507');
INSERT INTO public.ubigeo (district_id, code) VALUES (1035, '110508');
INSERT INTO public.ubigeo (district_id, code) VALUES (1036, '120101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1037, '120104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1038, '120105');
INSERT INTO public.ubigeo (district_id, code) VALUES (1039, '120106');
INSERT INTO public.ubigeo (district_id, code) VALUES (1040, '120107');
INSERT INTO public.ubigeo (district_id, code) VALUES (1041, '120108');
INSERT INTO public.ubigeo (district_id, code) VALUES (1042, '120111');
INSERT INTO public.ubigeo (district_id, code) VALUES (1043, '120112');
INSERT INTO public.ubigeo (district_id, code) VALUES (1044, '120113');
INSERT INTO public.ubigeo (district_id, code) VALUES (1045, '120114');
INSERT INTO public.ubigeo (district_id, code) VALUES (1046, '120116');
INSERT INTO public.ubigeo (district_id, code) VALUES (1047, '120117');
INSERT INTO public.ubigeo (district_id, code) VALUES (1048, '120119');
INSERT INTO public.ubigeo (district_id, code) VALUES (1049, '120120');
INSERT INTO public.ubigeo (district_id, code) VALUES (1050, '120121');
INSERT INTO public.ubigeo (district_id, code) VALUES (1051, '120122');
INSERT INTO public.ubigeo (district_id, code) VALUES (1052, '120124');
INSERT INTO public.ubigeo (district_id, code) VALUES (1053, '120125');
INSERT INTO public.ubigeo (district_id, code) VALUES (1054, '120126');
INSERT INTO public.ubigeo (district_id, code) VALUES (1055, '120127');
INSERT INTO public.ubigeo (district_id, code) VALUES (1056, '120128');
INSERT INTO public.ubigeo (district_id, code) VALUES (1057, '120129');
INSERT INTO public.ubigeo (district_id, code) VALUES (1058, '120130');
INSERT INTO public.ubigeo (district_id, code) VALUES (1059, '120132');
INSERT INTO public.ubigeo (district_id, code) VALUES (1060, '120133');
INSERT INTO public.ubigeo (district_id, code) VALUES (1061, '120134');
INSERT INTO public.ubigeo (district_id, code) VALUES (1062, '120135');
INSERT INTO public.ubigeo (district_id, code) VALUES (1063, '120136');
INSERT INTO public.ubigeo (district_id, code) VALUES (1064, '120201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1065, '120202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1066, '120203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1067, '120204');
INSERT INTO public.ubigeo (district_id, code) VALUES (1068, '120205');
INSERT INTO public.ubigeo (district_id, code) VALUES (1069, '120206');
INSERT INTO public.ubigeo (district_id, code) VALUES (1070, '120207');
INSERT INTO public.ubigeo (district_id, code) VALUES (1071, '120208');
INSERT INTO public.ubigeo (district_id, code) VALUES (1072, '120209');
INSERT INTO public.ubigeo (district_id, code) VALUES (1073, '120210');
INSERT INTO public.ubigeo (district_id, code) VALUES (1074, '120211');
INSERT INTO public.ubigeo (district_id, code) VALUES (1075, '120212');
INSERT INTO public.ubigeo (district_id, code) VALUES (1076, '120213');
INSERT INTO public.ubigeo (district_id, code) VALUES (1077, '120214');
INSERT INTO public.ubigeo (district_id, code) VALUES (1078, '120215');
INSERT INTO public.ubigeo (district_id, code) VALUES (1079, '120301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1080, '120302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1081, '120303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1082, '120304');
INSERT INTO public.ubigeo (district_id, code) VALUES (1083, '120305');
INSERT INTO public.ubigeo (district_id, code) VALUES (1084, '120306');
INSERT INTO public.ubigeo (district_id, code) VALUES (1085, '120401');
INSERT INTO public.ubigeo (district_id, code) VALUES (1086, '120402');
INSERT INTO public.ubigeo (district_id, code) VALUES (1087, '120403');
INSERT INTO public.ubigeo (district_id, code) VALUES (1088, '120404');
INSERT INTO public.ubigeo (district_id, code) VALUES (1089, '120405');
INSERT INTO public.ubigeo (district_id, code) VALUES (1090, '120406');
INSERT INTO public.ubigeo (district_id, code) VALUES (1091, '120407');
INSERT INTO public.ubigeo (district_id, code) VALUES (1092, '120408');
INSERT INTO public.ubigeo (district_id, code) VALUES (1093, '120409');
INSERT INTO public.ubigeo (district_id, code) VALUES (1094, '120410');
INSERT INTO public.ubigeo (district_id, code) VALUES (1095, '120411');
INSERT INTO public.ubigeo (district_id, code) VALUES (1096, '120412');
INSERT INTO public.ubigeo (district_id, code) VALUES (1097, '120413');
INSERT INTO public.ubigeo (district_id, code) VALUES (1098, '120414');
INSERT INTO public.ubigeo (district_id, code) VALUES (1099, '120415');
INSERT INTO public.ubigeo (district_id, code) VALUES (1100, '120416');
INSERT INTO public.ubigeo (district_id, code) VALUES (1101, '120417');
INSERT INTO public.ubigeo (district_id, code) VALUES (1102, '120418');
INSERT INTO public.ubigeo (district_id, code) VALUES (1103, '120419');
INSERT INTO public.ubigeo (district_id, code) VALUES (1104, '120420');
INSERT INTO public.ubigeo (district_id, code) VALUES (1105, '120421');
INSERT INTO public.ubigeo (district_id, code) VALUES (1106, '120422');
INSERT INTO public.ubigeo (district_id, code) VALUES (1107, '120423');
INSERT INTO public.ubigeo (district_id, code) VALUES (1108, '120424');
INSERT INTO public.ubigeo (district_id, code) VALUES (1109, '120425');
INSERT INTO public.ubigeo (district_id, code) VALUES (1110, '120426');
INSERT INTO public.ubigeo (district_id, code) VALUES (1111, '120427');
INSERT INTO public.ubigeo (district_id, code) VALUES (1112, '120428');
INSERT INTO public.ubigeo (district_id, code) VALUES (1113, '120429');
INSERT INTO public.ubigeo (district_id, code) VALUES (1114, '120430');
INSERT INTO public.ubigeo (district_id, code) VALUES (1115, '120431');
INSERT INTO public.ubigeo (district_id, code) VALUES (1116, '120432');
INSERT INTO public.ubigeo (district_id, code) VALUES (1117, '120433');
INSERT INTO public.ubigeo (district_id, code) VALUES (1118, '120434');
INSERT INTO public.ubigeo (district_id, code) VALUES (1119, '120501');
INSERT INTO public.ubigeo (district_id, code) VALUES (1120, '120502');
INSERT INTO public.ubigeo (district_id, code) VALUES (1121, '120503');
INSERT INTO public.ubigeo (district_id, code) VALUES (1122, '120504');
INSERT INTO public.ubigeo (district_id, code) VALUES (1123, '120601');
INSERT INTO public.ubigeo (district_id, code) VALUES (1124, '120602');
INSERT INTO public.ubigeo (district_id, code) VALUES (1125, '120603');
INSERT INTO public.ubigeo (district_id, code) VALUES (1126, '120604');
INSERT INTO public.ubigeo (district_id, code) VALUES (1127, '120605');
INSERT INTO public.ubigeo (district_id, code) VALUES (1128, '120606');
INSERT INTO public.ubigeo (district_id, code) VALUES (1129, '120607');
INSERT INTO public.ubigeo (district_id, code) VALUES (1130, '120608');
INSERT INTO public.ubigeo (district_id, code) VALUES (1131, '120609');
INSERT INTO public.ubigeo (district_id, code) VALUES (1132, '120701');
INSERT INTO public.ubigeo (district_id, code) VALUES (1133, '120702');
INSERT INTO public.ubigeo (district_id, code) VALUES (1134, '120703');
INSERT INTO public.ubigeo (district_id, code) VALUES (1135, '120704');
INSERT INTO public.ubigeo (district_id, code) VALUES (1136, '120705');
INSERT INTO public.ubigeo (district_id, code) VALUES (1137, '120706');
INSERT INTO public.ubigeo (district_id, code) VALUES (1138, '120707');
INSERT INTO public.ubigeo (district_id, code) VALUES (1139, '120708');
INSERT INTO public.ubigeo (district_id, code) VALUES (1140, '120709');
INSERT INTO public.ubigeo (district_id, code) VALUES (1141, '120801');
INSERT INTO public.ubigeo (district_id, code) VALUES (1142, '120802');
INSERT INTO public.ubigeo (district_id, code) VALUES (1143, '120803');
INSERT INTO public.ubigeo (district_id, code) VALUES (1144, '120804');
INSERT INTO public.ubigeo (district_id, code) VALUES (1145, '120805');
INSERT INTO public.ubigeo (district_id, code) VALUES (1146, '120806');
INSERT INTO public.ubigeo (district_id, code) VALUES (1147, '120807');
INSERT INTO public.ubigeo (district_id, code) VALUES (1148, '120808');
INSERT INTO public.ubigeo (district_id, code) VALUES (1149, '120809');
INSERT INTO public.ubigeo (district_id, code) VALUES (1150, '120810');
INSERT INTO public.ubigeo (district_id, code) VALUES (1151, '120901');
INSERT INTO public.ubigeo (district_id, code) VALUES (1152, '120902');
INSERT INTO public.ubigeo (district_id, code) VALUES (1153, '120903');
INSERT INTO public.ubigeo (district_id, code) VALUES (1154, '120904');
INSERT INTO public.ubigeo (district_id, code) VALUES (1155, '120905');
INSERT INTO public.ubigeo (district_id, code) VALUES (1156, '120906');
INSERT INTO public.ubigeo (district_id, code) VALUES (1157, '120907');
INSERT INTO public.ubigeo (district_id, code) VALUES (1158, '120908');
INSERT INTO public.ubigeo (district_id, code) VALUES (1159, '120909');
INSERT INTO public.ubigeo (district_id, code) VALUES (1160, '130101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1161, '130102');
INSERT INTO public.ubigeo (district_id, code) VALUES (1162, '130103');
INSERT INTO public.ubigeo (district_id, code) VALUES (1163, '130104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1164, '130105');
INSERT INTO public.ubigeo (district_id, code) VALUES (1165, '130106');
INSERT INTO public.ubigeo (district_id, code) VALUES (1166, '130107');
INSERT INTO public.ubigeo (district_id, code) VALUES (1167, '130108');
INSERT INTO public.ubigeo (district_id, code) VALUES (1168, '130109');
INSERT INTO public.ubigeo (district_id, code) VALUES (1169, '130110');
INSERT INTO public.ubigeo (district_id, code) VALUES (1170, '130111');
INSERT INTO public.ubigeo (district_id, code) VALUES (1171, '130201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1172, '130202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1173, '130203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1174, '130204');
INSERT INTO public.ubigeo (district_id, code) VALUES (1175, '130205');
INSERT INTO public.ubigeo (district_id, code) VALUES (1176, '130206');
INSERT INTO public.ubigeo (district_id, code) VALUES (1177, '130207');
INSERT INTO public.ubigeo (district_id, code) VALUES (1178, '130208');
INSERT INTO public.ubigeo (district_id, code) VALUES (1179, '130301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1180, '130302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1181, '130303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1182, '130304');
INSERT INTO public.ubigeo (district_id, code) VALUES (1183, '130305');
INSERT INTO public.ubigeo (district_id, code) VALUES (1184, '130306');
INSERT INTO public.ubigeo (district_id, code) VALUES (1185, '130401');
INSERT INTO public.ubigeo (district_id, code) VALUES (1186, '130402');
INSERT INTO public.ubigeo (district_id, code) VALUES (1187, '130403');
INSERT INTO public.ubigeo (district_id, code) VALUES (1188, '130501');
INSERT INTO public.ubigeo (district_id, code) VALUES (1189, '130502');
INSERT INTO public.ubigeo (district_id, code) VALUES (1190, '130503');
INSERT INTO public.ubigeo (district_id, code) VALUES (1191, '130504');
INSERT INTO public.ubigeo (district_id, code) VALUES (1192, '130601');
INSERT INTO public.ubigeo (district_id, code) VALUES (1193, '130602');
INSERT INTO public.ubigeo (district_id, code) VALUES (1194, '130604');
INSERT INTO public.ubigeo (district_id, code) VALUES (1195, '130605');
INSERT INTO public.ubigeo (district_id, code) VALUES (1196, '130606');
INSERT INTO public.ubigeo (district_id, code) VALUES (1197, '130608');
INSERT INTO public.ubigeo (district_id, code) VALUES (1198, '130610');
INSERT INTO public.ubigeo (district_id, code) VALUES (1199, '130611');
INSERT INTO public.ubigeo (district_id, code) VALUES (1200, '130613');
INSERT INTO public.ubigeo (district_id, code) VALUES (1201, '130614');
INSERT INTO public.ubigeo (district_id, code) VALUES (1202, '130701');
INSERT INTO public.ubigeo (district_id, code) VALUES (1203, '130702');
INSERT INTO public.ubigeo (district_id, code) VALUES (1204, '130703');
INSERT INTO public.ubigeo (district_id, code) VALUES (1205, '130704');
INSERT INTO public.ubigeo (district_id, code) VALUES (1206, '130705');
INSERT INTO public.ubigeo (district_id, code) VALUES (1207, '130801');
INSERT INTO public.ubigeo (district_id, code) VALUES (1208, '130802');
INSERT INTO public.ubigeo (district_id, code) VALUES (1209, '130803');
INSERT INTO public.ubigeo (district_id, code) VALUES (1210, '130804');
INSERT INTO public.ubigeo (district_id, code) VALUES (1211, '130805');
INSERT INTO public.ubigeo (district_id, code) VALUES (1212, '130806');
INSERT INTO public.ubigeo (district_id, code) VALUES (1213, '130807');
INSERT INTO public.ubigeo (district_id, code) VALUES (1214, '130808');
INSERT INTO public.ubigeo (district_id, code) VALUES (1215, '130809');
INSERT INTO public.ubigeo (district_id, code) VALUES (1216, '130810');
INSERT INTO public.ubigeo (district_id, code) VALUES (1217, '130811');
INSERT INTO public.ubigeo (district_id, code) VALUES (1218, '130812');
INSERT INTO public.ubigeo (district_id, code) VALUES (1219, '130813');
INSERT INTO public.ubigeo (district_id, code) VALUES (1220, '130901');
INSERT INTO public.ubigeo (district_id, code) VALUES (1221, '130902');
INSERT INTO public.ubigeo (district_id, code) VALUES (1222, '130903');
INSERT INTO public.ubigeo (district_id, code) VALUES (1223, '130904');
INSERT INTO public.ubigeo (district_id, code) VALUES (1224, '130905');
INSERT INTO public.ubigeo (district_id, code) VALUES (1225, '130906');
INSERT INTO public.ubigeo (district_id, code) VALUES (1226, '130907');
INSERT INTO public.ubigeo (district_id, code) VALUES (1227, '130908');
INSERT INTO public.ubigeo (district_id, code) VALUES (1228, '131001');
INSERT INTO public.ubigeo (district_id, code) VALUES (1229, '131002');
INSERT INTO public.ubigeo (district_id, code) VALUES (1230, '131003');
INSERT INTO public.ubigeo (district_id, code) VALUES (1231, '131004');
INSERT INTO public.ubigeo (district_id, code) VALUES (1232, '131005');
INSERT INTO public.ubigeo (district_id, code) VALUES (1233, '131006');
INSERT INTO public.ubigeo (district_id, code) VALUES (1234, '131007');
INSERT INTO public.ubigeo (district_id, code) VALUES (1235, '131008');
INSERT INTO public.ubigeo (district_id, code) VALUES (1236, '131101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1237, '131102');
INSERT INTO public.ubigeo (district_id, code) VALUES (1238, '131103');
INSERT INTO public.ubigeo (district_id, code) VALUES (1239, '131104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1240, '131201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1241, '131202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1242, '131203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1243, '140101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1244, '140102');
INSERT INTO public.ubigeo (district_id, code) VALUES (1245, '140103');
INSERT INTO public.ubigeo (district_id, code) VALUES (1246, '140104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1247, '140105');
INSERT INTO public.ubigeo (district_id, code) VALUES (1248, '140106');
INSERT INTO public.ubigeo (district_id, code) VALUES (1249, '140107');
INSERT INTO public.ubigeo (district_id, code) VALUES (1250, '140108');
INSERT INTO public.ubigeo (district_id, code) VALUES (1251, '140109');
INSERT INTO public.ubigeo (district_id, code) VALUES (1252, '140110');
INSERT INTO public.ubigeo (district_id, code) VALUES (1253, '140111');
INSERT INTO public.ubigeo (district_id, code) VALUES (1254, '140112');
INSERT INTO public.ubigeo (district_id, code) VALUES (1255, '140113');
INSERT INTO public.ubigeo (district_id, code) VALUES (1256, '140114');
INSERT INTO public.ubigeo (district_id, code) VALUES (1257, '140115');
INSERT INTO public.ubigeo (district_id, code) VALUES (1258, '140116');
INSERT INTO public.ubigeo (district_id, code) VALUES (1259, '140117');
INSERT INTO public.ubigeo (district_id, code) VALUES (1260, '140118');
INSERT INTO public.ubigeo (district_id, code) VALUES (1261, '140119');
INSERT INTO public.ubigeo (district_id, code) VALUES (1262, '140120');
INSERT INTO public.ubigeo (district_id, code) VALUES (1263, '140201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1264, '140202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1265, '140203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1266, '140204');
INSERT INTO public.ubigeo (district_id, code) VALUES (1267, '140205');
INSERT INTO public.ubigeo (district_id, code) VALUES (1268, '140206');
INSERT INTO public.ubigeo (district_id, code) VALUES (1269, '140301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1270, '140302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1271, '140303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1272, '140304');
INSERT INTO public.ubigeo (district_id, code) VALUES (1273, '140305');
INSERT INTO public.ubigeo (district_id, code) VALUES (1274, '140306');
INSERT INTO public.ubigeo (district_id, code) VALUES (1275, '140307');
INSERT INTO public.ubigeo (district_id, code) VALUES (1276, '140308');
INSERT INTO public.ubigeo (district_id, code) VALUES (1277, '140309');
INSERT INTO public.ubigeo (district_id, code) VALUES (1278, '140310');
INSERT INTO public.ubigeo (district_id, code) VALUES (1279, '140311');
INSERT INTO public.ubigeo (district_id, code) VALUES (1280, '140312');
INSERT INTO public.ubigeo (district_id, code) VALUES (1281, '150101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1282, '150102');
INSERT INTO public.ubigeo (district_id, code) VALUES (1283, '150103');
INSERT INTO public.ubigeo (district_id, code) VALUES (1284, '150104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1285, '150105');
INSERT INTO public.ubigeo (district_id, code) VALUES (1286, '150106');
INSERT INTO public.ubigeo (district_id, code) VALUES (1287, '150107');
INSERT INTO public.ubigeo (district_id, code) VALUES (1288, '150108');
INSERT INTO public.ubigeo (district_id, code) VALUES (1289, '150109');
INSERT INTO public.ubigeo (district_id, code) VALUES (1290, '150110');
INSERT INTO public.ubigeo (district_id, code) VALUES (1291, '150111');
INSERT INTO public.ubigeo (district_id, code) VALUES (1292, '150112');
INSERT INTO public.ubigeo (district_id, code) VALUES (1293, '150113');
INSERT INTO public.ubigeo (district_id, code) VALUES (1294, '150114');
INSERT INTO public.ubigeo (district_id, code) VALUES (1295, '150115');
INSERT INTO public.ubigeo (district_id, code) VALUES (1296, '150116');
INSERT INTO public.ubigeo (district_id, code) VALUES (1297, '150117');
INSERT INTO public.ubigeo (district_id, code) VALUES (1298, '150118');
INSERT INTO public.ubigeo (district_id, code) VALUES (1299, '150119');
INSERT INTO public.ubigeo (district_id, code) VALUES (1300, '150120');
INSERT INTO public.ubigeo (district_id, code) VALUES (1301, '150121');
INSERT INTO public.ubigeo (district_id, code) VALUES (1302, '150122');
INSERT INTO public.ubigeo (district_id, code) VALUES (1303, '150123');
INSERT INTO public.ubigeo (district_id, code) VALUES (1304, '150124');
INSERT INTO public.ubigeo (district_id, code) VALUES (1305, '150125');
INSERT INTO public.ubigeo (district_id, code) VALUES (1306, '150126');
INSERT INTO public.ubigeo (district_id, code) VALUES (1307, '150127');
INSERT INTO public.ubigeo (district_id, code) VALUES (1308, '150128');
INSERT INTO public.ubigeo (district_id, code) VALUES (1309, '150129');
INSERT INTO public.ubigeo (district_id, code) VALUES (1310, '150130');
INSERT INTO public.ubigeo (district_id, code) VALUES (1311, '150131');
INSERT INTO public.ubigeo (district_id, code) VALUES (1312, '150132');
INSERT INTO public.ubigeo (district_id, code) VALUES (1313, '150133');
INSERT INTO public.ubigeo (district_id, code) VALUES (1314, '150134');
INSERT INTO public.ubigeo (district_id, code) VALUES (1315, '150135');
INSERT INTO public.ubigeo (district_id, code) VALUES (1316, '150136');
INSERT INTO public.ubigeo (district_id, code) VALUES (1317, '150137');
INSERT INTO public.ubigeo (district_id, code) VALUES (1318, '150138');
INSERT INTO public.ubigeo (district_id, code) VALUES (1319, '150139');
INSERT INTO public.ubigeo (district_id, code) VALUES (1320, '150140');
INSERT INTO public.ubigeo (district_id, code) VALUES (1321, '150141');
INSERT INTO public.ubigeo (district_id, code) VALUES (1322, '150142');
INSERT INTO public.ubigeo (district_id, code) VALUES (1323, '150143');
INSERT INTO public.ubigeo (district_id, code) VALUES (1324, '150201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1325, '150202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1326, '150203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1327, '150204');
INSERT INTO public.ubigeo (district_id, code) VALUES (1328, '150205');
INSERT INTO public.ubigeo (district_id, code) VALUES (1329, '150301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1330, '150302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1331, '150303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1332, '150304');
INSERT INTO public.ubigeo (district_id, code) VALUES (1333, '150305');
INSERT INTO public.ubigeo (district_id, code) VALUES (1334, '150401');
INSERT INTO public.ubigeo (district_id, code) VALUES (1335, '150402');
INSERT INTO public.ubigeo (district_id, code) VALUES (1336, '150403');
INSERT INTO public.ubigeo (district_id, code) VALUES (1337, '150404');
INSERT INTO public.ubigeo (district_id, code) VALUES (1338, '150405');
INSERT INTO public.ubigeo (district_id, code) VALUES (1339, '150406');
INSERT INTO public.ubigeo (district_id, code) VALUES (1340, '150407');
INSERT INTO public.ubigeo (district_id, code) VALUES (1341, '150501');
INSERT INTO public.ubigeo (district_id, code) VALUES (1342, '150502');
INSERT INTO public.ubigeo (district_id, code) VALUES (1343, '150503');
INSERT INTO public.ubigeo (district_id, code) VALUES (1344, '150504');
INSERT INTO public.ubigeo (district_id, code) VALUES (1345, '150505');
INSERT INTO public.ubigeo (district_id, code) VALUES (1346, '150506');
INSERT INTO public.ubigeo (district_id, code) VALUES (1347, '150507');
INSERT INTO public.ubigeo (district_id, code) VALUES (1348, '150508');
INSERT INTO public.ubigeo (district_id, code) VALUES (1349, '150509');
INSERT INTO public.ubigeo (district_id, code) VALUES (1350, '150510');
INSERT INTO public.ubigeo (district_id, code) VALUES (1351, '150511');
INSERT INTO public.ubigeo (district_id, code) VALUES (1352, '150512');
INSERT INTO public.ubigeo (district_id, code) VALUES (1353, '150513');
INSERT INTO public.ubigeo (district_id, code) VALUES (1354, '150514');
INSERT INTO public.ubigeo (district_id, code) VALUES (1355, '150515');
INSERT INTO public.ubigeo (district_id, code) VALUES (1356, '150516');
INSERT INTO public.ubigeo (district_id, code) VALUES (1357, '150601');
INSERT INTO public.ubigeo (district_id, code) VALUES (1358, '150602');
INSERT INTO public.ubigeo (district_id, code) VALUES (1359, '150603');
INSERT INTO public.ubigeo (district_id, code) VALUES (1360, '150604');
INSERT INTO public.ubigeo (district_id, code) VALUES (1361, '150605');
INSERT INTO public.ubigeo (district_id, code) VALUES (1362, '150606');
INSERT INTO public.ubigeo (district_id, code) VALUES (1363, '150607');
INSERT INTO public.ubigeo (district_id, code) VALUES (1364, '150608');
INSERT INTO public.ubigeo (district_id, code) VALUES (1365, '150609');
INSERT INTO public.ubigeo (district_id, code) VALUES (1366, '150610');
INSERT INTO public.ubigeo (district_id, code) VALUES (1367, '150611');
INSERT INTO public.ubigeo (district_id, code) VALUES (1368, '150612');
INSERT INTO public.ubigeo (district_id, code) VALUES (1369, '150701');
INSERT INTO public.ubigeo (district_id, code) VALUES (1370, '150702');
INSERT INTO public.ubigeo (district_id, code) VALUES (1371, '150703');
INSERT INTO public.ubigeo (district_id, code) VALUES (1372, '150704');
INSERT INTO public.ubigeo (district_id, code) VALUES (1373, '150705');
INSERT INTO public.ubigeo (district_id, code) VALUES (1374, '150706');
INSERT INTO public.ubigeo (district_id, code) VALUES (1375, '150707');
INSERT INTO public.ubigeo (district_id, code) VALUES (1376, '150708');
INSERT INTO public.ubigeo (district_id, code) VALUES (1377, '150709');
INSERT INTO public.ubigeo (district_id, code) VALUES (1378, '150710');
INSERT INTO public.ubigeo (district_id, code) VALUES (1379, '150711');
INSERT INTO public.ubigeo (district_id, code) VALUES (1380, '150712');
INSERT INTO public.ubigeo (district_id, code) VALUES (1381, '150713');
INSERT INTO public.ubigeo (district_id, code) VALUES (1382, '150714');
INSERT INTO public.ubigeo (district_id, code) VALUES (1383, '150715');
INSERT INTO public.ubigeo (district_id, code) VALUES (1384, '150716');
INSERT INTO public.ubigeo (district_id, code) VALUES (1385, '150717');
INSERT INTO public.ubigeo (district_id, code) VALUES (1386, '150718');
INSERT INTO public.ubigeo (district_id, code) VALUES (1387, '150719');
INSERT INTO public.ubigeo (district_id, code) VALUES (1388, '150720');
INSERT INTO public.ubigeo (district_id, code) VALUES (1389, '150721');
INSERT INTO public.ubigeo (district_id, code) VALUES (1390, '150722');
INSERT INTO public.ubigeo (district_id, code) VALUES (1391, '150723');
INSERT INTO public.ubigeo (district_id, code) VALUES (1392, '150724');
INSERT INTO public.ubigeo (district_id, code) VALUES (1393, '150725');
INSERT INTO public.ubigeo (district_id, code) VALUES (1394, '150726');
INSERT INTO public.ubigeo (district_id, code) VALUES (1395, '150727');
INSERT INTO public.ubigeo (district_id, code) VALUES (1396, '150728');
INSERT INTO public.ubigeo (district_id, code) VALUES (1397, '150729');
INSERT INTO public.ubigeo (district_id, code) VALUES (1398, '150730');
INSERT INTO public.ubigeo (district_id, code) VALUES (1399, '150731');
INSERT INTO public.ubigeo (district_id, code) VALUES (1400, '150732');
INSERT INTO public.ubigeo (district_id, code) VALUES (1401, '150801');
INSERT INTO public.ubigeo (district_id, code) VALUES (1402, '150802');
INSERT INTO public.ubigeo (district_id, code) VALUES (1403, '150803');
INSERT INTO public.ubigeo (district_id, code) VALUES (1404, '150804');
INSERT INTO public.ubigeo (district_id, code) VALUES (1405, '150805');
INSERT INTO public.ubigeo (district_id, code) VALUES (1406, '150806');
INSERT INTO public.ubigeo (district_id, code) VALUES (1407, '150807');
INSERT INTO public.ubigeo (district_id, code) VALUES (1408, '150808');
INSERT INTO public.ubigeo (district_id, code) VALUES (1409, '150809');
INSERT INTO public.ubigeo (district_id, code) VALUES (1410, '150810');
INSERT INTO public.ubigeo (district_id, code) VALUES (1411, '150811');
INSERT INTO public.ubigeo (district_id, code) VALUES (1412, '150812');
INSERT INTO public.ubigeo (district_id, code) VALUES (1413, '150901');
INSERT INTO public.ubigeo (district_id, code) VALUES (1414, '150902');
INSERT INTO public.ubigeo (district_id, code) VALUES (1415, '150903');
INSERT INTO public.ubigeo (district_id, code) VALUES (1416, '150904');
INSERT INTO public.ubigeo (district_id, code) VALUES (1417, '150905');
INSERT INTO public.ubigeo (district_id, code) VALUES (1418, '150906');
INSERT INTO public.ubigeo (district_id, code) VALUES (1419, '151001');
INSERT INTO public.ubigeo (district_id, code) VALUES (1420, '151002');
INSERT INTO public.ubigeo (district_id, code) VALUES (1421, '151003');
INSERT INTO public.ubigeo (district_id, code) VALUES (1422, '151004');
INSERT INTO public.ubigeo (district_id, code) VALUES (1423, '151005');
INSERT INTO public.ubigeo (district_id, code) VALUES (1424, '151006');
INSERT INTO public.ubigeo (district_id, code) VALUES (1425, '151007');
INSERT INTO public.ubigeo (district_id, code) VALUES (1426, '151008');
INSERT INTO public.ubigeo (district_id, code) VALUES (1427, '151009');
INSERT INTO public.ubigeo (district_id, code) VALUES (1428, '151010');
INSERT INTO public.ubigeo (district_id, code) VALUES (1429, '151011');
INSERT INTO public.ubigeo (district_id, code) VALUES (1430, '151012');
INSERT INTO public.ubigeo (district_id, code) VALUES (1431, '151013');
INSERT INTO public.ubigeo (district_id, code) VALUES (1432, '151014');
INSERT INTO public.ubigeo (district_id, code) VALUES (1433, '151015');
INSERT INTO public.ubigeo (district_id, code) VALUES (1434, '151016');
INSERT INTO public.ubigeo (district_id, code) VALUES (1435, '151017');
INSERT INTO public.ubigeo (district_id, code) VALUES (1436, '151018');
INSERT INTO public.ubigeo (district_id, code) VALUES (1437, '151019');
INSERT INTO public.ubigeo (district_id, code) VALUES (1438, '151020');
INSERT INTO public.ubigeo (district_id, code) VALUES (1439, '151021');
INSERT INTO public.ubigeo (district_id, code) VALUES (1440, '151022');
INSERT INTO public.ubigeo (district_id, code) VALUES (1441, '151023');
INSERT INTO public.ubigeo (district_id, code) VALUES (1442, '151024');
INSERT INTO public.ubigeo (district_id, code) VALUES (1443, '151025');
INSERT INTO public.ubigeo (district_id, code) VALUES (1444, '151026');
INSERT INTO public.ubigeo (district_id, code) VALUES (1445, '151027');
INSERT INTO public.ubigeo (district_id, code) VALUES (1446, '151028');
INSERT INTO public.ubigeo (district_id, code) VALUES (1447, '151029');
INSERT INTO public.ubigeo (district_id, code) VALUES (1448, '151030');
INSERT INTO public.ubigeo (district_id, code) VALUES (1449, '151031');
INSERT INTO public.ubigeo (district_id, code) VALUES (1450, '151032');
INSERT INTO public.ubigeo (district_id, code) VALUES (1451, '151033');
INSERT INTO public.ubigeo (district_id, code) VALUES (1452, '160101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1453, '160102');
INSERT INTO public.ubigeo (district_id, code) VALUES (1454, '160103');
INSERT INTO public.ubigeo (district_id, code) VALUES (1455, '160104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1456, '160105');
INSERT INTO public.ubigeo (district_id, code) VALUES (1457, '160106');
INSERT INTO public.ubigeo (district_id, code) VALUES (1458, '160107');
INSERT INTO public.ubigeo (district_id, code) VALUES (1459, '160108');
INSERT INTO public.ubigeo (district_id, code) VALUES (1460, '160110');
INSERT INTO public.ubigeo (district_id, code) VALUES (1461, '160112');
INSERT INTO public.ubigeo (district_id, code) VALUES (1462, '160113');
INSERT INTO public.ubigeo (district_id, code) VALUES (1463, '160201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1464, '160202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1465, '160205');
INSERT INTO public.ubigeo (district_id, code) VALUES (1466, '160206');
INSERT INTO public.ubigeo (district_id, code) VALUES (1467, '160210');
INSERT INTO public.ubigeo (district_id, code) VALUES (1468, '160211');
INSERT INTO public.ubigeo (district_id, code) VALUES (1469, '160301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1470, '160302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1471, '160303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1472, '160304');
INSERT INTO public.ubigeo (district_id, code) VALUES (1473, '160305');
INSERT INTO public.ubigeo (district_id, code) VALUES (1474, '160401');
INSERT INTO public.ubigeo (district_id, code) VALUES (1475, '160402');
INSERT INTO public.ubigeo (district_id, code) VALUES (1476, '160403');
INSERT INTO public.ubigeo (district_id, code) VALUES (1477, '160404');
INSERT INTO public.ubigeo (district_id, code) VALUES (1478, '160501');
INSERT INTO public.ubigeo (district_id, code) VALUES (1479, '160502');
INSERT INTO public.ubigeo (district_id, code) VALUES (1480, '160503');
INSERT INTO public.ubigeo (district_id, code) VALUES (1481, '160504');
INSERT INTO public.ubigeo (district_id, code) VALUES (1482, '160505');
INSERT INTO public.ubigeo (district_id, code) VALUES (1483, '160506');
INSERT INTO public.ubigeo (district_id, code) VALUES (1484, '160507');
INSERT INTO public.ubigeo (district_id, code) VALUES (1485, '160508');
INSERT INTO public.ubigeo (district_id, code) VALUES (1486, '160509');
INSERT INTO public.ubigeo (district_id, code) VALUES (1487, '160510');
INSERT INTO public.ubigeo (district_id, code) VALUES (1488, '160511');
INSERT INTO public.ubigeo (district_id, code) VALUES (1489, '160601');
INSERT INTO public.ubigeo (district_id, code) VALUES (1490, '160602');
INSERT INTO public.ubigeo (district_id, code) VALUES (1491, '160603');
INSERT INTO public.ubigeo (district_id, code) VALUES (1492, '160604');
INSERT INTO public.ubigeo (district_id, code) VALUES (1493, '160605');
INSERT INTO public.ubigeo (district_id, code) VALUES (1494, '160606');
INSERT INTO public.ubigeo (district_id, code) VALUES (1495, '160701');
INSERT INTO public.ubigeo (district_id, code) VALUES (1496, '160702');
INSERT INTO public.ubigeo (district_id, code) VALUES (1497, '160703');
INSERT INTO public.ubigeo (district_id, code) VALUES (1498, '160704');
INSERT INTO public.ubigeo (district_id, code) VALUES (1499, '160705');
INSERT INTO public.ubigeo (district_id, code) VALUES (1500, '160706');
INSERT INTO public.ubigeo (district_id, code) VALUES (1501, '160801');
INSERT INTO public.ubigeo (district_id, code) VALUES (1502, '160802');
INSERT INTO public.ubigeo (district_id, code) VALUES (1503, '160803');
INSERT INTO public.ubigeo (district_id, code) VALUES (1504, '160804');
INSERT INTO public.ubigeo (district_id, code) VALUES (1505, '170101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1506, '170102');
INSERT INTO public.ubigeo (district_id, code) VALUES (1507, '170103');
INSERT INTO public.ubigeo (district_id, code) VALUES (1508, '170104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1509, '170201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1510, '170202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1511, '170203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1512, '170204');
INSERT INTO public.ubigeo (district_id, code) VALUES (1513, '170301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1514, '170302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1515, '170303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1516, '180101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1517, '180102');
INSERT INTO public.ubigeo (district_id, code) VALUES (1518, '180103');
INSERT INTO public.ubigeo (district_id, code) VALUES (1519, '180104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1520, '180105');
INSERT INTO public.ubigeo (district_id, code) VALUES (1521, '180106');
INSERT INTO public.ubigeo (district_id, code) VALUES (1522, '180201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1523, '180202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1524, '180203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1525, '180204');
INSERT INTO public.ubigeo (district_id, code) VALUES (1526, '180205');
INSERT INTO public.ubigeo (district_id, code) VALUES (1527, '180206');
INSERT INTO public.ubigeo (district_id, code) VALUES (1528, '180207');
INSERT INTO public.ubigeo (district_id, code) VALUES (1529, '180208');
INSERT INTO public.ubigeo (district_id, code) VALUES (1530, '180209');
INSERT INTO public.ubigeo (district_id, code) VALUES (1531, '180210');
INSERT INTO public.ubigeo (district_id, code) VALUES (1532, '180211');
INSERT INTO public.ubigeo (district_id, code) VALUES (1533, '180301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1534, '180302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1535, '180303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1536, '190101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1537, '190102');
INSERT INTO public.ubigeo (district_id, code) VALUES (1538, '190103');
INSERT INTO public.ubigeo (district_id, code) VALUES (1539, '190104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1540, '190105');
INSERT INTO public.ubigeo (district_id, code) VALUES (1541, '190106');
INSERT INTO public.ubigeo (district_id, code) VALUES (1542, '190107');
INSERT INTO public.ubigeo (district_id, code) VALUES (1543, '190108');
INSERT INTO public.ubigeo (district_id, code) VALUES (1544, '190109');
INSERT INTO public.ubigeo (district_id, code) VALUES (1545, '190110');
INSERT INTO public.ubigeo (district_id, code) VALUES (1546, '190111');
INSERT INTO public.ubigeo (district_id, code) VALUES (1547, '190112');
INSERT INTO public.ubigeo (district_id, code) VALUES (1548, '190113');
INSERT INTO public.ubigeo (district_id, code) VALUES (1549, '190201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1550, '190202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1551, '190203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1552, '190204');
INSERT INTO public.ubigeo (district_id, code) VALUES (1553, '190205');
INSERT INTO public.ubigeo (district_id, code) VALUES (1554, '190206');
INSERT INTO public.ubigeo (district_id, code) VALUES (1555, '190207');
INSERT INTO public.ubigeo (district_id, code) VALUES (1556, '190208');
INSERT INTO public.ubigeo (district_id, code) VALUES (1557, '190301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1558, '190302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1559, '190303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1560, '190304');
INSERT INTO public.ubigeo (district_id, code) VALUES (1561, '190305');
INSERT INTO public.ubigeo (district_id, code) VALUES (1562, '190306');
INSERT INTO public.ubigeo (district_id, code) VALUES (1563, '190307');
INSERT INTO public.ubigeo (district_id, code) VALUES (1564, '190308');
INSERT INTO public.ubigeo (district_id, code) VALUES (1565, '200101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1566, '200104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1567, '200105');
INSERT INTO public.ubigeo (district_id, code) VALUES (1568, '200107');
INSERT INTO public.ubigeo (district_id, code) VALUES (1569, '200108');
INSERT INTO public.ubigeo (district_id, code) VALUES (1570, '200109');
INSERT INTO public.ubigeo (district_id, code) VALUES (1571, '200110');
INSERT INTO public.ubigeo (district_id, code) VALUES (1572, '200111');
INSERT INTO public.ubigeo (district_id, code) VALUES (1573, '200114');
INSERT INTO public.ubigeo (district_id, code) VALUES (1574, '200115');
INSERT INTO public.ubigeo (district_id, code) VALUES (1575, '200201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1576, '200202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1577, '200203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1578, '200204');
INSERT INTO public.ubigeo (district_id, code) VALUES (1579, '200205');
INSERT INTO public.ubigeo (district_id, code) VALUES (1580, '200206');
INSERT INTO public.ubigeo (district_id, code) VALUES (1581, '200207');
INSERT INTO public.ubigeo (district_id, code) VALUES (1582, '200208');
INSERT INTO public.ubigeo (district_id, code) VALUES (1583, '200209');
INSERT INTO public.ubigeo (district_id, code) VALUES (1584, '200210');
INSERT INTO public.ubigeo (district_id, code) VALUES (1585, '200301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1586, '200302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1587, '200303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1588, '200304');
INSERT INTO public.ubigeo (district_id, code) VALUES (1589, '200305');
INSERT INTO public.ubigeo (district_id, code) VALUES (1590, '200306');
INSERT INTO public.ubigeo (district_id, code) VALUES (1591, '200307');
INSERT INTO public.ubigeo (district_id, code) VALUES (1592, '200308');
INSERT INTO public.ubigeo (district_id, code) VALUES (1593, '200401');
INSERT INTO public.ubigeo (district_id, code) VALUES (1594, '200402');
INSERT INTO public.ubigeo (district_id, code) VALUES (1595, '200403');
INSERT INTO public.ubigeo (district_id, code) VALUES (1596, '200404');
INSERT INTO public.ubigeo (district_id, code) VALUES (1597, '200405');
INSERT INTO public.ubigeo (district_id, code) VALUES (1598, '200406');
INSERT INTO public.ubigeo (district_id, code) VALUES (1599, '200407');
INSERT INTO public.ubigeo (district_id, code) VALUES (1600, '200408');
INSERT INTO public.ubigeo (district_id, code) VALUES (1601, '200409');
INSERT INTO public.ubigeo (district_id, code) VALUES (1602, '200410');
INSERT INTO public.ubigeo (district_id, code) VALUES (1603, '200501');
INSERT INTO public.ubigeo (district_id, code) VALUES (1604, '200502');
INSERT INTO public.ubigeo (district_id, code) VALUES (1605, '200503');
INSERT INTO public.ubigeo (district_id, code) VALUES (1606, '200504');
INSERT INTO public.ubigeo (district_id, code) VALUES (1607, '200505');
INSERT INTO public.ubigeo (district_id, code) VALUES (1608, '200506');
INSERT INTO public.ubigeo (district_id, code) VALUES (1609, '200507');
INSERT INTO public.ubigeo (district_id, code) VALUES (1610, '200601');
INSERT INTO public.ubigeo (district_id, code) VALUES (1611, '200602');
INSERT INTO public.ubigeo (district_id, code) VALUES (1612, '200603');
INSERT INTO public.ubigeo (district_id, code) VALUES (1613, '200604');
INSERT INTO public.ubigeo (district_id, code) VALUES (1614, '200605');
INSERT INTO public.ubigeo (district_id, code) VALUES (1615, '200606');
INSERT INTO public.ubigeo (district_id, code) VALUES (1616, '200607');
INSERT INTO public.ubigeo (district_id, code) VALUES (1617, '200608');
INSERT INTO public.ubigeo (district_id, code) VALUES (1618, '200701');
INSERT INTO public.ubigeo (district_id, code) VALUES (1619, '200702');
INSERT INTO public.ubigeo (district_id, code) VALUES (1620, '200703');
INSERT INTO public.ubigeo (district_id, code) VALUES (1621, '200704');
INSERT INTO public.ubigeo (district_id, code) VALUES (1622, '200705');
INSERT INTO public.ubigeo (district_id, code) VALUES (1623, '200706');
INSERT INTO public.ubigeo (district_id, code) VALUES (1624, '200801');
INSERT INTO public.ubigeo (district_id, code) VALUES (1625, '200802');
INSERT INTO public.ubigeo (district_id, code) VALUES (1626, '200803');
INSERT INTO public.ubigeo (district_id, code) VALUES (1627, '200804');
INSERT INTO public.ubigeo (district_id, code) VALUES (1628, '200805');
INSERT INTO public.ubigeo (district_id, code) VALUES (1629, '200806');
INSERT INTO public.ubigeo (district_id, code) VALUES (1630, '210101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1631, '210102');
INSERT INTO public.ubigeo (district_id, code) VALUES (1632, '210103');
INSERT INTO public.ubigeo (district_id, code) VALUES (1633, '210104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1634, '210105');
INSERT INTO public.ubigeo (district_id, code) VALUES (1635, '210106');
INSERT INTO public.ubigeo (district_id, code) VALUES (1636, '210107');
INSERT INTO public.ubigeo (district_id, code) VALUES (1637, '210108');
INSERT INTO public.ubigeo (district_id, code) VALUES (1638, '210109');
INSERT INTO public.ubigeo (district_id, code) VALUES (1639, '210110');
INSERT INTO public.ubigeo (district_id, code) VALUES (1640, '210111');
INSERT INTO public.ubigeo (district_id, code) VALUES (1641, '210112');
INSERT INTO public.ubigeo (district_id, code) VALUES (1642, '210113');
INSERT INTO public.ubigeo (district_id, code) VALUES (1643, '210114');
INSERT INTO public.ubigeo (district_id, code) VALUES (1644, '210115');
INSERT INTO public.ubigeo (district_id, code) VALUES (1645, '210201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1646, '210202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1647, '210203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1648, '210204');
INSERT INTO public.ubigeo (district_id, code) VALUES (1649, '210205');
INSERT INTO public.ubigeo (district_id, code) VALUES (1650, '210206');
INSERT INTO public.ubigeo (district_id, code) VALUES (1651, '210207');
INSERT INTO public.ubigeo (district_id, code) VALUES (1652, '210208');
INSERT INTO public.ubigeo (district_id, code) VALUES (1653, '210209');
INSERT INTO public.ubigeo (district_id, code) VALUES (1654, '210210');
INSERT INTO public.ubigeo (district_id, code) VALUES (1655, '210211');
INSERT INTO public.ubigeo (district_id, code) VALUES (1656, '210212');
INSERT INTO public.ubigeo (district_id, code) VALUES (1657, '210213');
INSERT INTO public.ubigeo (district_id, code) VALUES (1658, '210214');
INSERT INTO public.ubigeo (district_id, code) VALUES (1659, '210215');
INSERT INTO public.ubigeo (district_id, code) VALUES (1660, '210301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1661, '210302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1662, '210303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1663, '210304');
INSERT INTO public.ubigeo (district_id, code) VALUES (1664, '210305');
INSERT INTO public.ubigeo (district_id, code) VALUES (1665, '210306');
INSERT INTO public.ubigeo (district_id, code) VALUES (1666, '210307');
INSERT INTO public.ubigeo (district_id, code) VALUES (1667, '210308');
INSERT INTO public.ubigeo (district_id, code) VALUES (1668, '210309');
INSERT INTO public.ubigeo (district_id, code) VALUES (1669, '210310');
INSERT INTO public.ubigeo (district_id, code) VALUES (1670, '210401');
INSERT INTO public.ubigeo (district_id, code) VALUES (1671, '210402');
INSERT INTO public.ubigeo (district_id, code) VALUES (1672, '210403');
INSERT INTO public.ubigeo (district_id, code) VALUES (1673, '210404');
INSERT INTO public.ubigeo (district_id, code) VALUES (1674, '210405');
INSERT INTO public.ubigeo (district_id, code) VALUES (1675, '210406');
INSERT INTO public.ubigeo (district_id, code) VALUES (1676, '210407');
INSERT INTO public.ubigeo (district_id, code) VALUES (1677, '210501');
INSERT INTO public.ubigeo (district_id, code) VALUES (1678, '210502');
INSERT INTO public.ubigeo (district_id, code) VALUES (1679, '210503');
INSERT INTO public.ubigeo (district_id, code) VALUES (1680, '210504');
INSERT INTO public.ubigeo (district_id, code) VALUES (1681, '210505');
INSERT INTO public.ubigeo (district_id, code) VALUES (1682, '210601');
INSERT INTO public.ubigeo (district_id, code) VALUES (1683, '210602');
INSERT INTO public.ubigeo (district_id, code) VALUES (1684, '210603');
INSERT INTO public.ubigeo (district_id, code) VALUES (1685, '210604');
INSERT INTO public.ubigeo (district_id, code) VALUES (1686, '210605');
INSERT INTO public.ubigeo (district_id, code) VALUES (1687, '210606');
INSERT INTO public.ubigeo (district_id, code) VALUES (1688, '210607');
INSERT INTO public.ubigeo (district_id, code) VALUES (1689, '210608');
INSERT INTO public.ubigeo (district_id, code) VALUES (1690, '210701');
INSERT INTO public.ubigeo (district_id, code) VALUES (1691, '210702');
INSERT INTO public.ubigeo (district_id, code) VALUES (1692, '210703');
INSERT INTO public.ubigeo (district_id, code) VALUES (1693, '210704');
INSERT INTO public.ubigeo (district_id, code) VALUES (1694, '210705');
INSERT INTO public.ubigeo (district_id, code) VALUES (1695, '210706');
INSERT INTO public.ubigeo (district_id, code) VALUES (1696, '210707');
INSERT INTO public.ubigeo (district_id, code) VALUES (1697, '210708');
INSERT INTO public.ubigeo (district_id, code) VALUES (1698, '210709');
INSERT INTO public.ubigeo (district_id, code) VALUES (1699, '210710');
INSERT INTO public.ubigeo (district_id, code) VALUES (1700, '210801');
INSERT INTO public.ubigeo (district_id, code) VALUES (1701, '210802');
INSERT INTO public.ubigeo (district_id, code) VALUES (1702, '210803');
INSERT INTO public.ubigeo (district_id, code) VALUES (1703, '210804');
INSERT INTO public.ubigeo (district_id, code) VALUES (1704, '210805');
INSERT INTO public.ubigeo (district_id, code) VALUES (1705, '210806');
INSERT INTO public.ubigeo (district_id, code) VALUES (1706, '210807');
INSERT INTO public.ubigeo (district_id, code) VALUES (1707, '210808');
INSERT INTO public.ubigeo (district_id, code) VALUES (1708, '210809');
INSERT INTO public.ubigeo (district_id, code) VALUES (1709, '210901');
INSERT INTO public.ubigeo (district_id, code) VALUES (1710, '210902');
INSERT INTO public.ubigeo (district_id, code) VALUES (1711, '210903');
INSERT INTO public.ubigeo (district_id, code) VALUES (1712, '210904');
INSERT INTO public.ubigeo (district_id, code) VALUES (1713, '211001');
INSERT INTO public.ubigeo (district_id, code) VALUES (1714, '211002');
INSERT INTO public.ubigeo (district_id, code) VALUES (1715, '211003');
INSERT INTO public.ubigeo (district_id, code) VALUES (1716, '211004');
INSERT INTO public.ubigeo (district_id, code) VALUES (1717, '211005');
INSERT INTO public.ubigeo (district_id, code) VALUES (1718, '211101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1719, '211102');
INSERT INTO public.ubigeo (district_id, code) VALUES (1720, '211103');
INSERT INTO public.ubigeo (district_id, code) VALUES (1721, '211104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1722, '211105');
INSERT INTO public.ubigeo (district_id, code) VALUES (1723, '211201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1724, '211202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1725, '211203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1726, '211204');
INSERT INTO public.ubigeo (district_id, code) VALUES (1727, '211205');
INSERT INTO public.ubigeo (district_id, code) VALUES (1728, '211206');
INSERT INTO public.ubigeo (district_id, code) VALUES (1729, '211207');
INSERT INTO public.ubigeo (district_id, code) VALUES (1730, '211208');
INSERT INTO public.ubigeo (district_id, code) VALUES (1731, '211209');
INSERT INTO public.ubigeo (district_id, code) VALUES (1732, '211210');
INSERT INTO public.ubigeo (district_id, code) VALUES (1733, '211301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1734, '211302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1735, '211303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1736, '211304');
INSERT INTO public.ubigeo (district_id, code) VALUES (1737, '211305');
INSERT INTO public.ubigeo (district_id, code) VALUES (1738, '211306');
INSERT INTO public.ubigeo (district_id, code) VALUES (1739, '211307');
INSERT INTO public.ubigeo (district_id, code) VALUES (1740, '220101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1741, '220102');
INSERT INTO public.ubigeo (district_id, code) VALUES (1742, '220103');
INSERT INTO public.ubigeo (district_id, code) VALUES (1743, '220104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1744, '220105');
INSERT INTO public.ubigeo (district_id, code) VALUES (1745, '220106');
INSERT INTO public.ubigeo (district_id, code) VALUES (1746, '220201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1747, '220202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1748, '220203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1749, '220204');
INSERT INTO public.ubigeo (district_id, code) VALUES (1750, '220205');
INSERT INTO public.ubigeo (district_id, code) VALUES (1751, '220206');
INSERT INTO public.ubigeo (district_id, code) VALUES (1752, '220301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1753, '220302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1754, '220303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1755, '220304');
INSERT INTO public.ubigeo (district_id, code) VALUES (1756, '220305');
INSERT INTO public.ubigeo (district_id, code) VALUES (1757, '220401');
INSERT INTO public.ubigeo (district_id, code) VALUES (1758, '220402');
INSERT INTO public.ubigeo (district_id, code) VALUES (1759, '220403');
INSERT INTO public.ubigeo (district_id, code) VALUES (1760, '220404');
INSERT INTO public.ubigeo (district_id, code) VALUES (1761, '220405');
INSERT INTO public.ubigeo (district_id, code) VALUES (1762, '220406');
INSERT INTO public.ubigeo (district_id, code) VALUES (1763, '220501');
INSERT INTO public.ubigeo (district_id, code) VALUES (1764, '220502');
INSERT INTO public.ubigeo (district_id, code) VALUES (1765, '220503');
INSERT INTO public.ubigeo (district_id, code) VALUES (1766, '220504');
INSERT INTO public.ubigeo (district_id, code) VALUES (1767, '220505');
INSERT INTO public.ubigeo (district_id, code) VALUES (1768, '220506');
INSERT INTO public.ubigeo (district_id, code) VALUES (1769, '220507');
INSERT INTO public.ubigeo (district_id, code) VALUES (1770, '220508');
INSERT INTO public.ubigeo (district_id, code) VALUES (1771, '220509');
INSERT INTO public.ubigeo (district_id, code) VALUES (1772, '220510');
INSERT INTO public.ubigeo (district_id, code) VALUES (1773, '220511');
INSERT INTO public.ubigeo (district_id, code) VALUES (1774, '220601');
INSERT INTO public.ubigeo (district_id, code) VALUES (1775, '220602');
INSERT INTO public.ubigeo (district_id, code) VALUES (1776, '220603');
INSERT INTO public.ubigeo (district_id, code) VALUES (1777, '220604');
INSERT INTO public.ubigeo (district_id, code) VALUES (1778, '220605');
INSERT INTO public.ubigeo (district_id, code) VALUES (1779, '220701');
INSERT INTO public.ubigeo (district_id, code) VALUES (1780, '220702');
INSERT INTO public.ubigeo (district_id, code) VALUES (1781, '220703');
INSERT INTO public.ubigeo (district_id, code) VALUES (1782, '220704');
INSERT INTO public.ubigeo (district_id, code) VALUES (1783, '220705');
INSERT INTO public.ubigeo (district_id, code) VALUES (1784, '220706');
INSERT INTO public.ubigeo (district_id, code) VALUES (1785, '220707');
INSERT INTO public.ubigeo (district_id, code) VALUES (1786, '220708');
INSERT INTO public.ubigeo (district_id, code) VALUES (1787, '220709');
INSERT INTO public.ubigeo (district_id, code) VALUES (1788, '220710');
INSERT INTO public.ubigeo (district_id, code) VALUES (1789, '220801');
INSERT INTO public.ubigeo (district_id, code) VALUES (1790, '220802');
INSERT INTO public.ubigeo (district_id, code) VALUES (1791, '220803');
INSERT INTO public.ubigeo (district_id, code) VALUES (1792, '220804');
INSERT INTO public.ubigeo (district_id, code) VALUES (1793, '220805');
INSERT INTO public.ubigeo (district_id, code) VALUES (1794, '220806');
INSERT INTO public.ubigeo (district_id, code) VALUES (1795, '220807');
INSERT INTO public.ubigeo (district_id, code) VALUES (1796, '220808');
INSERT INTO public.ubigeo (district_id, code) VALUES (1797, '220809');
INSERT INTO public.ubigeo (district_id, code) VALUES (1798, '220901');
INSERT INTO public.ubigeo (district_id, code) VALUES (1799, '220902');
INSERT INTO public.ubigeo (district_id, code) VALUES (1800, '220903');
INSERT INTO public.ubigeo (district_id, code) VALUES (1801, '220904');
INSERT INTO public.ubigeo (district_id, code) VALUES (1802, '220905');
INSERT INTO public.ubigeo (district_id, code) VALUES (1803, '220906');
INSERT INTO public.ubigeo (district_id, code) VALUES (1804, '220907');
INSERT INTO public.ubigeo (district_id, code) VALUES (1805, '220908');
INSERT INTO public.ubigeo (district_id, code) VALUES (1806, '220909');
INSERT INTO public.ubigeo (district_id, code) VALUES (1807, '220910');
INSERT INTO public.ubigeo (district_id, code) VALUES (1808, '220911');
INSERT INTO public.ubigeo (district_id, code) VALUES (1809, '220912');
INSERT INTO public.ubigeo (district_id, code) VALUES (1810, '220913');
INSERT INTO public.ubigeo (district_id, code) VALUES (1811, '220914');
INSERT INTO public.ubigeo (district_id, code) VALUES (1812, '221001');
INSERT INTO public.ubigeo (district_id, code) VALUES (1813, '221002');
INSERT INTO public.ubigeo (district_id, code) VALUES (1814, '221003');
INSERT INTO public.ubigeo (district_id, code) VALUES (1815, '221004');
INSERT INTO public.ubigeo (district_id, code) VALUES (1816, '221005');
INSERT INTO public.ubigeo (district_id, code) VALUES (1817, '230101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1818, '230102');
INSERT INTO public.ubigeo (district_id, code) VALUES (1819, '230103');
INSERT INTO public.ubigeo (district_id, code) VALUES (1820, '230104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1821, '230105');
INSERT INTO public.ubigeo (district_id, code) VALUES (1822, '230106');
INSERT INTO public.ubigeo (district_id, code) VALUES (1823, '230107');
INSERT INTO public.ubigeo (district_id, code) VALUES (1824, '230108');
INSERT INTO public.ubigeo (district_id, code) VALUES (1825, '230109');
INSERT INTO public.ubigeo (district_id, code) VALUES (1826, '230110');
INSERT INTO public.ubigeo (district_id, code) VALUES (1827, '230111');
INSERT INTO public.ubigeo (district_id, code) VALUES (1828, '230201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1829, '230202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1830, '230203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1831, '230204');
INSERT INTO public.ubigeo (district_id, code) VALUES (1832, '230205');
INSERT INTO public.ubigeo (district_id, code) VALUES (1833, '230206');
INSERT INTO public.ubigeo (district_id, code) VALUES (1834, '230301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1835, '230302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1836, '230303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1837, '230401');
INSERT INTO public.ubigeo (district_id, code) VALUES (1838, '230402');
INSERT INTO public.ubigeo (district_id, code) VALUES (1839, '230403');
INSERT INTO public.ubigeo (district_id, code) VALUES (1840, '230404');
INSERT INTO public.ubigeo (district_id, code) VALUES (1841, '230405');
INSERT INTO public.ubigeo (district_id, code) VALUES (1842, '230406');
INSERT INTO public.ubigeo (district_id, code) VALUES (1843, '230407');
INSERT INTO public.ubigeo (district_id, code) VALUES (1844, '230408');
INSERT INTO public.ubigeo (district_id, code) VALUES (1845, '240101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1846, '240102');
INSERT INTO public.ubigeo (district_id, code) VALUES (1847, '240103');
INSERT INTO public.ubigeo (district_id, code) VALUES (1848, '240104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1849, '240105');
INSERT INTO public.ubigeo (district_id, code) VALUES (1850, '240106');
INSERT INTO public.ubigeo (district_id, code) VALUES (1851, '240201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1852, '240202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1853, '240203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1854, '240301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1855, '240302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1856, '240303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1857, '240304');
INSERT INTO public.ubigeo (district_id, code) VALUES (1858, '250101');
INSERT INTO public.ubigeo (district_id, code) VALUES (1859, '250102');
INSERT INTO public.ubigeo (district_id, code) VALUES (1860, '250103');
INSERT INTO public.ubigeo (district_id, code) VALUES (1861, '250104');
INSERT INTO public.ubigeo (district_id, code) VALUES (1862, '250105');
INSERT INTO public.ubigeo (district_id, code) VALUES (1863, '250106');
INSERT INTO public.ubigeo (district_id, code) VALUES (1864, '250107');
INSERT INTO public.ubigeo (district_id, code) VALUES (1865, '250201');
INSERT INTO public.ubigeo (district_id, code) VALUES (1866, '250202');
INSERT INTO public.ubigeo (district_id, code) VALUES (1867, '250203');
INSERT INTO public.ubigeo (district_id, code) VALUES (1868, '250204');
INSERT INTO public.ubigeo (district_id, code) VALUES (1869, '250301');
INSERT INTO public.ubigeo (district_id, code) VALUES (1870, '250302');
INSERT INTO public.ubigeo (district_id, code) VALUES (1871, '250303');
INSERT INTO public.ubigeo (district_id, code) VALUES (1872, '250304');
INSERT INTO public.ubigeo (district_id, code) VALUES (1873, '250305');
INSERT INTO public.ubigeo (district_id, code) VALUES (1874, '250401');


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.user_roles (user_id, role_id) VALUES (3, 7);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users (id, names, paternal_lastname, maternal_lastname, email, hashed_password, phone, is_active) VALUES (3, 'Admin', 'User', 'User', 'admin@srj.local', '$argon2id$v=19$m=65536,t=3,p=1$LRGr4HvFQ3kVORVDmjawgQ$8UHQ8kN3AQ5mXkROcgCBOGcjYQmUHA5E9TaBPRr2wF0', '900000000', true);


--
-- Data for Name: work_areas; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.work_areas (id, name) VALUES (1, 'Dirección');
INSERT INTO public.work_areas (id, name) VALUES (2, 'Personal Docente');
INSERT INTO public.work_areas (id, name) VALUES (3, 'Personal Auxiliar de Educación');
INSERT INTO public.work_areas (id, name) VALUES (4, 'Mantenimiento');
INSERT INTO public.work_areas (id, name) VALUES (5, 'Contabilidad');
INSERT INTO public.work_areas (id, name) VALUES (6, 'Departamento de Computación');
INSERT INTO public.work_areas (id, name) VALUES (7, 'Departamento de Psicología');
INSERT INTO public.work_areas (id, name) VALUES (8, 'Departamento de Cocina');
INSERT INTO public.work_areas (id, name) VALUES (9, 'Administración');
INSERT INTO public.work_areas (id, name) VALUES (10, 'Practicantes');
INSERT INTO public.work_areas (id, name) VALUES (11, 'Subdirección');
INSERT INTO public.work_areas (id, name) VALUES (12, 'Secretaria');


--
-- Name: academic_grades_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.academic_grades_id_seq', 14, true);


--
-- Name: academic_levels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.academic_levels_id_seq', 3, true);


--
-- Name: accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.accounts_id_seq', 469, true);


--
-- Name: audit_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.audit_log_id_seq', 1, false);


--
-- Name: charge_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.charge_types_id_seq', 3, true);


--
-- Name: childbirth_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.childbirth_type_id_seq', 3, true);


--
-- Name: civil_state_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.civil_state_id_seq', 4, true);


--
-- Name: debt_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.debt_statuses_id_seq', 5, true);


--
-- Name: department_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.department_id_seq', 1874, true);


--
-- Name: disability_degrees_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.disability_degrees_id_seq', 4, true);


--
-- Name: disability_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.disability_types_id_seq', 9, true);


--
-- Name: district_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.district_id_seq', 1874, true);


--
-- Name: document_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.document_types_id_seq', 5, true);


--
-- Name: employment_contract_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.employment_contract_id_seq', 3, true);


--
-- Name: enrollment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.enrollment_id_seq', 20, true);


--
-- Name: enrollment_states_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.enrollment_states_id_seq', 4, true);


--
-- Name: ethnic_self_identifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ethnic_self_identifications_id_seq', 5, true);


--
-- Name: familiar_relationship_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.familiar_relationship_type_id_seq', 10, true);


--
-- Name: familiar_student_relationship_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.familiar_student_relationship_id_seq', 53, true);


--
-- Name: genders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.genders_id_seq', 2, true);


--
-- Name: grade_offering_shift_sections_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.grade_offering_shift_sections_id_seq', 607, true);


--
-- Name: grade_offering_shifts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.grade_offering_shifts_id_seq', 265, true);


--
-- Name: grade_offerings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.grade_offerings_id_seq', 245, true);


--
-- Name: institution_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.institution_id_seq', 3, true);


--
-- Name: job_positions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.job_positions_id_seq', 28, true);


--
-- Name: languages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.languages_id_seq', 35, true);


--
-- Name: level_of_education_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.level_of_education_id_seq', 22, true);


--
-- Name: lunch_assignments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lunch_assignments_id_seq', 160, true);


--
-- Name: lunch_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lunch_categories_id_seq', 12, true);


--
-- Name: lunches_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lunches_id_seq', 82, true);


--
-- Name: payment_debt_allocations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.payment_debt_allocations_id_seq', 45, true);


--
-- Name: payment_methods_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.payment_methods_id_seq', 6, true);


--
-- Name: payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.payments_id_seq', 33, true);


--
-- Name: permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.permissions_id_seq', 82, true);


--
-- Name: person_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.person_id_seq', 48, true);


--
-- Name: province_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.province_id_seq', 1874, true);


--
-- Name: religion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.religion_id_seq', 12, true);


--
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.roles_id_seq', 9, true);


--
-- Name: ruc_states_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ruc_states_id_seq', 6, true);


--
-- Name: school_fee_concepts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.school_fee_concepts_id_seq', 5, true);


--
-- Name: school_fee_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.school_fee_id_seq', 554, true);


--
-- Name: school_year_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.school_year_id_seq', 22, true);


--
-- Name: school_year_months_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.school_year_months_id_seq', 220, true);


--
-- Name: shifts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.shifts_id_seq', 2, true);


--
-- Name: student_debts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.student_debts_id_seq', 109, true);


--
-- Name: student_states_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.student_states_id_seq', 4, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.users_id_seq', 3, true);


--
-- Name: work_areas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.work_areas_id_seq', 12, true);


--
-- Name: grades academic_grades_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grades
    ADD CONSTRAINT academic_grades_pkey PRIMARY KEY (id);


--
-- Name: levels academic_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.levels
    ADD CONSTRAINT academic_levels_pkey PRIMARY KEY (id);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: charge_types charge_types_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_types
    ADD CONSTRAINT charge_types_code_key UNIQUE (code);


--
-- Name: charge_types charge_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_types
    ADD CONSTRAINT charge_types_pkey PRIMARY KEY (id);


--
-- Name: childbirth_type childbirth_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.childbirth_type
    ADD CONSTRAINT childbirth_type_pkey PRIMARY KEY (id);


--
-- Name: civil_state civil_state_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.civil_state
    ADD CONSTRAINT civil_state_name_key UNIQUE (name);


--
-- Name: civil_state civil_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.civil_state
    ADD CONSTRAINT civil_state_pkey PRIMARY KEY (id);


--
-- Name: debt_statuses debt_statuses_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debt_statuses
    ADD CONSTRAINT debt_statuses_code_key UNIQUE (code);


--
-- Name: debt_statuses debt_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debt_statuses
    ADD CONSTRAINT debt_statuses_pkey PRIMARY KEY (id);


--
-- Name: department department_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.department
    ADD CONSTRAINT department_code_key UNIQUE (code);


--
-- Name: department department_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.department
    ADD CONSTRAINT department_name_key UNIQUE (name);


--
-- Name: department department_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.department
    ADD CONSTRAINT department_pkey PRIMARY KEY (id);


--
-- Name: disabilities disabilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disabilities
    ADD CONSTRAINT disabilities_pkey PRIMARY KEY (student_id);


--
-- Name: disability_degrees disability_degrees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disability_degrees
    ADD CONSTRAINT disability_degrees_pkey PRIMARY KEY (id);


--
-- Name: disability_types disability_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disability_types
    ADD CONSTRAINT disability_types_pkey PRIMARY KEY (id);


--
-- Name: district district_code_province_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.district
    ADD CONSTRAINT district_code_province_id_key UNIQUE (code, province_id);


--
-- Name: district district_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.district
    ADD CONSTRAINT district_pkey PRIMARY KEY (id);


--
-- Name: document_types document_types_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_types
    ADD CONSTRAINT document_types_name_key UNIQUE (name);


--
-- Name: document_types document_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_types
    ADD CONSTRAINT document_types_pkey PRIMARY KEY (id);


--
-- Name: employment_contract employment_contract_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_contract
    ADD CONSTRAINT employment_contract_pkey PRIMARY KEY (id);


--
-- Name: enrollment enrollment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment
    ADD CONSTRAINT enrollment_pkey PRIMARY KEY (id);


--
-- Name: enrollment_states enrollment_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment_states
    ADD CONSTRAINT enrollment_states_pkey PRIMARY KEY (id);


--
-- Name: ethnic_self_identifications ethnic_self_identifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ethnic_self_identifications
    ADD CONSTRAINT ethnic_self_identifications_pkey PRIMARY KEY (id);


--
-- Name: familiar_relationship_type familiar_relationship_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiar_relationship_type
    ADD CONSTRAINT familiar_relationship_type_pkey PRIMARY KEY (id);


--
-- Name: familiar_student_relationship familiar_student_relationship_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiar_student_relationship
    ADD CONSTRAINT familiar_student_relationship_pkey PRIMARY KEY (id);


--
-- Name: familiars familiars_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiars
    ADD CONSTRAINT familiars_pkey PRIMARY KEY (person_id);


--
-- Name: genders genders_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.genders
    ADD CONSTRAINT genders_name_key UNIQUE (name);


--
-- Name: genders genders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.genders
    ADD CONSTRAINT genders_pkey PRIMARY KEY (id);


--
-- Name: grade_offering_shift_sections grade_offering_shift_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_offering_shift_sections
    ADD CONSTRAINT grade_offering_shift_sections_pkey PRIMARY KEY (id);


--
-- Name: grade_offering_shifts grade_offering_shifts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_offering_shifts
    ADD CONSTRAINT grade_offering_shifts_pkey PRIMARY KEY (id);


--
-- Name: grade_offerings grade_offerings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_offerings
    ADD CONSTRAINT grade_offerings_pkey PRIMARY KEY (id);


--
-- Name: institution institution_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution
    ADD CONSTRAINT institution_name_key UNIQUE (name);


--
-- Name: institution institution_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution
    ADD CONSTRAINT institution_pkey PRIMARY KEY (id);


--
-- Name: institution institution_ruc_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution
    ADD CONSTRAINT institution_ruc_key UNIQUE (ruc);


--
-- Name: job_positions job_positions_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_positions
    ADD CONSTRAINT job_positions_name_key UNIQUE (name);


--
-- Name: job_positions job_positions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_positions
    ADD CONSTRAINT job_positions_pkey PRIMARY KEY (id);


--
-- Name: languages languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.languages
    ADD CONSTRAINT languages_pkey PRIMARY KEY (id);


--
-- Name: level_of_education level_of_education_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_of_education
    ADD CONSTRAINT level_of_education_name_key UNIQUE (name);


--
-- Name: level_of_education level_of_education_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_of_education
    ADD CONSTRAINT level_of_education_pkey PRIMARY KEY (id);


--
-- Name: lunch_assignments lunch_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lunch_assignments
    ADD CONSTRAINT lunch_assignments_pkey PRIMARY KEY (id);


--
-- Name: lunch_categories lunch_categories_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lunch_categories
    ADD CONSTRAINT lunch_categories_name_key UNIQUE (name);


--
-- Name: lunch_categories lunch_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lunch_categories
    ADD CONSTRAINT lunch_categories_pkey PRIMARY KEY (id);


--
-- Name: lunches lunches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lunches
    ADD CONSTRAINT lunches_pkey PRIMARY KEY (id);


--
-- Name: payment_debt_allocations payment_debt_allocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_debt_allocations
    ADD CONSTRAINT payment_debt_allocations_pkey PRIMARY KEY (id);


--
-- Name: payment_methods payment_methods_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_name_key UNIQUE (name);


--
-- Name: payment_methods payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: person person_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_pkey PRIMARY KEY (id);


--
-- Name: province province_code_department_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.province
    ADD CONSTRAINT province_code_department_id_key UNIQUE (code, department_id);


--
-- Name: province province_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.province
    ADD CONSTRAINT province_pkey PRIMARY KEY (id);


--
-- Name: religion religion_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.religion
    ADD CONSTRAINT religion_name_key UNIQUE (name);


--
-- Name: religion religion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.religion
    ADD CONSTRAINT religion_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (role_id, permission_id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: ruc_states ruc_states_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ruc_states
    ADD CONSTRAINT ruc_states_name_key UNIQUE (name);


--
-- Name: ruc_states ruc_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ruc_states
    ADD CONSTRAINT ruc_states_pkey PRIMARY KEY (id);


--
-- Name: school_fee_concepts school_fee_concepts_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_fee_concepts
    ADD CONSTRAINT school_fee_concepts_name_key UNIQUE (name);


--
-- Name: school_fee_concepts school_fee_concepts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_fee_concepts
    ADD CONSTRAINT school_fee_concepts_pkey PRIMARY KEY (id);


--
-- Name: school_fee school_fee_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_fee
    ADD CONSTRAINT school_fee_pkey PRIMARY KEY (id);


--
-- Name: school_year_months school_year_months_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_year_months
    ADD CONSTRAINT school_year_months_pkey PRIMARY KEY (id);


--
-- Name: school_year school_year_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_year
    ADD CONSTRAINT school_year_pkey PRIMARY KEY (id);


--
-- Name: school_year school_year_year_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_year
    ADD CONSTRAINT school_year_year_key UNIQUE (year);


--
-- Name: second_languages second_languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.second_languages
    ADD CONSTRAINT second_languages_pkey PRIMARY KEY (person_id, second_language_id);


--
-- Name: shifts shifts_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shifts
    ADD CONSTRAINT shifts_name_key UNIQUE (name);


--
-- Name: shifts shifts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shifts
    ADD CONSTRAINT shifts_pkey PRIMARY KEY (id);


--
-- Name: staff_members staff_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_members
    ADD CONSTRAINT staff_members_pkey PRIMARY KEY (person_id);


--
-- Name: enrollment_debts student_debts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment_debts
    ADD CONSTRAINT student_debts_pkey PRIMARY KEY (id);


--
-- Name: student_homes student_homes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_homes
    ADD CONSTRAINT student_homes_pkey PRIMARY KEY (student_id);


--
-- Name: student_school_year_states student_states_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_school_year_states
    ADD CONSTRAINT student_states_name_key UNIQUE (name);


--
-- Name: student_school_year_states student_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_school_year_states
    ADD CONSTRAINT student_states_pkey PRIMARY KEY (id);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (person_id);


--
-- Name: ubigeo ubigeo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ubigeo
    ADD CONSTRAINT ubigeo_pkey PRIMARY KEY (district_id);


--
-- Name: person unique_document_type_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT unique_document_type_number UNIQUE (document_type_id, id_document_number);


--
-- Name: person unique_id_document_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT unique_id_document_number UNIQUE (id_document_number);


--
-- Name: enrollment unique_student_year_state; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment
    ADD CONSTRAINT unique_student_year_state UNIQUE (student_id, school_year_id, state_id);


--
-- Name: payment_debt_allocations uq_allocation_payment_debt; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_debt_allocations
    ADD CONSTRAINT uq_allocation_payment_debt UNIQUE (payment_id, debt_id);


--
-- Name: school_year_months uq_school_year_month; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_year_months
    ADD CONSTRAINT uq_school_year_month UNIQUE (school_year_id, month);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: work_areas work_areas_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_areas
    ADD CONSTRAINT work_areas_name_key UNIQUE (name);


--
-- Name: work_areas work_areas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_areas
    ADD CONSTRAINT work_areas_pkey PRIMARY KEY (id);


--
-- Name: idx_alloc_debt_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_alloc_debt_id ON public.payment_debt_allocations USING btree (debt_id);


--
-- Name: idx_alloc_payment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_alloc_payment_id ON public.payment_debt_allocations USING btree (payment_id);


--
-- Name: idx_district_province_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_district_province_id ON public.district USING btree (province_id);


--
-- Name: idx_enrollment_debts_unique_period; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_enrollment_debts_unique_period ON public.enrollment_debts USING btree (period_month, school_year_id, enrollment_id) WHERE (period_month IS NOT NULL);


--
-- Name: idx_languages_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_languages_name ON public.languages USING btree (name);


--
-- Name: idx_payments_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_created_by ON public.payments USING btree (created_by);


--
-- Name: idx_payments_voided; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_voided ON public.payments USING btree (is_voided) WHERE (is_voided = true);


--
-- Name: idx_province_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_province_department_id ON public.province USING btree (department_id);


--
-- Name: idx_student_debts_charge_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_student_debts_charge_type ON public.enrollment_debts USING btree (charge_type_id);


--
-- Name: idx_student_debts_due_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_student_debts_due_date ON public.enrollment_debts USING btree (due_date);


--
-- Name: idx_student_debts_enrollment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_student_debts_enrollment_id ON public.enrollment_debts USING btree (enrollment_id);


--
-- Name: idx_student_debts_school_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_student_debts_school_year ON public.enrollment_debts USING btree (school_year_id);


--
-- Name: idx_student_debts_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_student_debts_status_id ON public.enrollment_debts USING btree (status_id);


--
-- Name: idx_student_debts_student_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_student_debts_student_id ON public.enrollment_debts USING btree (student_id);


--
-- Name: idx_sym_billing_open_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sym_billing_open_date ON public.school_year_months USING btree (billing_open_date);


--
-- Name: idx_sym_school_year_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sym_school_year_id ON public.school_year_months USING btree (school_year_id);


--
-- Name: lunch_assignments_assigned_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lunch_assignments_assigned_date_idx ON public.lunch_assignments USING btree (assigned_date);


--
-- Name: lunch_assignments_enrollment_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lunch_assignments_enrollment_id_idx ON public.lunch_assignments USING btree (enrollment_id);


--
-- Name: lunch_assignments_has_debt_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lunch_assignments_has_debt_idx ON public.lunch_assignments USING btree (has_debt) WHERE (has_debt = true);


--
-- Name: lunch_assignments_lunch_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lunch_assignments_lunch_id_idx ON public.lunch_assignments USING btree (lunch_id);


--
-- Name: uq_debt_enrollment_fee; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_debt_enrollment_fee ON public.enrollment_debts USING btree (enrollment_id) WHERE (charge_type_id = 2);


--
-- Name: uq_debt_tuition_period; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_debt_tuition_period ON public.enrollment_debts USING btree (enrollment_id, period_month) WHERE (charge_type_id = 3);


--
-- Name: ubigeo trg_calc_ubigeo_code; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_calc_ubigeo_code BEFORE INSERT OR UPDATE ON public.ubigeo FOR EACH ROW EXECUTE FUNCTION public.calc_ubigeo_code();


--
-- Name: enrollment_debts trg_check_admission_uniqueness; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_admission_uniqueness BEFORE INSERT OR UPDATE ON public.enrollment_debts FOR EACH ROW EXECUTE FUNCTION public.check_admission_uniqueness();


--
-- Name: payment_debt_allocations trg_check_allocation_limit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_allocation_limit BEFORE INSERT OR UPDATE ON public.payment_debt_allocations FOR EACH ROW EXECUTE FUNCTION public.check_allocation_limit();


--
-- Name: enrollment_debts trg_check_debt_school_year_consistency; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_debt_school_year_consistency BEFORE INSERT OR UPDATE OF enrollment_id, school_year_id ON public.enrollment_debts FOR EACH ROW EXECUTE FUNCTION public.check_debt_school_year_consistency();


--
-- Name: enrollment trg_enrollment_unique_per_year; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_enrollment_unique_per_year BEFORE INSERT OR UPDATE OF student_id, grade_offering_shift_section_id ON public.enrollment FOR EACH ROW EXECUTE FUNCTION public.enrollment_unique_per_year();


--
-- Name: enrollment_debts trg_student_debts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_student_debts_updated_at BEFORE UPDATE ON public.enrollment_debts FOR EACH ROW EXECUTE FUNCTION public.set_student_debts_updated_at();


--
-- Name: payment_debt_allocations trg_update_debt_status; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_update_debt_status AFTER INSERT OR DELETE OR UPDATE ON public.payment_debt_allocations FOR EACH ROW EXECUTE FUNCTION public.update_debt_status();


--
-- Name: grades academic_grades_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grades
    ADD CONSTRAINT academic_grades_level_id_fkey FOREIGN KEY (level_id) REFERENCES public.levels(id) ON DELETE CASCADE;


--
-- Name: accounts accounts_parent_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_parent_account_id_fkey FOREIGN KEY (parent_account_id) REFERENCES public.accounts(id);


--
-- Name: disabilities disabilities_disability_degree_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disabilities
    ADD CONSTRAINT disabilities_disability_degree_id_fkey FOREIGN KEY (disability_degree_id) REFERENCES public.disability_degrees(id);


--
-- Name: disabilities disabilities_disability_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disabilities
    ADD CONSTRAINT disabilities_disability_type_id_fkey FOREIGN KEY (disability_type_id) REFERENCES public.disability_types(id);


--
-- Name: disabilities disabilities_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disabilities
    ADD CONSTRAINT disabilities_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(person_id);


--
-- Name: district district_province_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.district
    ADD CONSTRAINT district_province_id_fkey FOREIGN KEY (province_id) REFERENCES public.province(id);


--
-- Name: employment_contract employment_contract_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_contract
    ADD CONSTRAINT employment_contract_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.work_areas(id);


--
-- Name: employment_contract employment_contract_institution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_contract
    ADD CONSTRAINT employment_contract_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES public.institution(id);


--
-- Name: employment_contract employment_contract_job_position_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_contract
    ADD CONSTRAINT employment_contract_job_position_id_fkey FOREIGN KEY (job_position_id) REFERENCES public.job_positions(id);


--
-- Name: employment_contract employment_contract_school_year_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_contract
    ADD CONSTRAINT employment_contract_school_year_id_fkey FOREIGN KEY (school_year_id) REFERENCES public.school_year(id);


--
-- Name: employment_contract employment_contract_staff_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_contract
    ADD CONSTRAINT employment_contract_staff_member_id_fkey FOREIGN KEY (staff_member_id) REFERENCES public.staff_members(person_id);


--
-- Name: enrollment enrollment_grade_offering_shift_section_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment
    ADD CONSTRAINT enrollment_grade_offering_shift_section_id_fkey FOREIGN KEY (grade_offering_shift_section_id) REFERENCES public.grade_offering_shift_sections(id);


--
-- Name: enrollment enrollment_school_fee_concept_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment
    ADD CONSTRAINT enrollment_school_fee_concept_id_fkey FOREIGN KEY (school_fee_concept_id) REFERENCES public.school_fee_concepts(id);


--
-- Name: enrollment enrollment_school_year_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment
    ADD CONSTRAINT enrollment_school_year_id_fkey FOREIGN KEY (school_year_id) REFERENCES public.school_year(id);


--
-- Name: enrollment enrollment_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment
    ADD CONSTRAINT enrollment_state_id_fkey FOREIGN KEY (state_id) REFERENCES public.enrollment_states(id);


--
-- Name: enrollment enrollment_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment
    ADD CONSTRAINT enrollment_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(person_id);


--
-- Name: familiar_student_relationship familiar_student_relationship_familiar_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiar_student_relationship
    ADD CONSTRAINT familiar_student_relationship_familiar_id_fkey FOREIGN KEY (familiar_id) REFERENCES public.familiars(person_id);


--
-- Name: familiar_student_relationship familiar_student_relationship_familiar_relationship_type_i_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiar_student_relationship
    ADD CONSTRAINT familiar_student_relationship_familiar_relationship_type_i_fkey FOREIGN KEY (familiar_relationship_type_id) REFERENCES public.familiar_relationship_type(id);


--
-- Name: familiar_student_relationship familiar_student_relationship_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiar_student_relationship
    ADD CONSTRAINT familiar_student_relationship_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(person_id);


--
-- Name: familiars familiars_level_of_education_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiars
    ADD CONSTRAINT familiars_level_of_education_id_fkey FOREIGN KEY (level_of_education_id) REFERENCES public.level_of_education(id);


--
-- Name: familiars familiars_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiars
    ADD CONSTRAINT familiars_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.person(id);


--
-- Name: grade_offering_shift_sections grade_offering_shift_sections_grade_offering_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_offering_shift_sections
    ADD CONSTRAINT grade_offering_shift_sections_grade_offering_shift_id_fkey FOREIGN KEY (grade_offering_shift_id) REFERENCES public.grade_offering_shifts(id);


--
-- Name: grade_offering_shifts grade_offering_shifts_grade_offering_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_offering_shifts
    ADD CONSTRAINT grade_offering_shifts_grade_offering_id_fkey FOREIGN KEY (grade_offering_id) REFERENCES public.grade_offerings(id);


--
-- Name: grade_offering_shifts grade_offering_shifts_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_offering_shifts
    ADD CONSTRAINT grade_offering_shifts_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES public.shifts(id);


--
-- Name: grade_offerings grade_offerings_grade_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_offerings
    ADD CONSTRAINT grade_offerings_grade_id_fkey FOREIGN KEY (grade_id) REFERENCES public.grades(id);


--
-- Name: grade_offerings grade_offerings_school_year_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_offerings
    ADD CONSTRAINT grade_offerings_school_year_id_fkey FOREIGN KEY (school_year_id) REFERENCES public.school_year(id);


--
-- Name: institution_levels institution_levels_institution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_levels
    ADD CONSTRAINT institution_levels_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES public.institution(id);


--
-- Name: institution_levels institution_levels_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_levels
    ADD CONSTRAINT institution_levels_level_id_fkey FOREIGN KEY (level_id) REFERENCES public.levels(id);


--
-- Name: institution institution_ruc_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution
    ADD CONSTRAINT institution_ruc_state_id_fkey FOREIGN KEY (ruc_state_id) REFERENCES public.ruc_states(id);


--
-- Name: lunch_assignments lunch_assignments_assigned_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lunch_assignments
    ADD CONSTRAINT lunch_assignments_assigned_by_id_fkey FOREIGN KEY (assigned_by_id) REFERENCES public.users(id);


--
-- Name: lunch_assignments lunch_assignments_enrollment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lunch_assignments
    ADD CONSTRAINT lunch_assignments_enrollment_id_fkey FOREIGN KEY (enrollment_id) REFERENCES public.enrollment(id);


--
-- Name: lunch_assignments lunch_assignments_lunch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lunch_assignments
    ADD CONSTRAINT lunch_assignments_lunch_id_fkey FOREIGN KEY (lunch_id) REFERENCES public.lunches(id);


--
-- Name: lunch_assignments lunch_assignments_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lunch_assignments
    ADD CONSTRAINT lunch_assignments_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.person(id);


--
-- Name: lunch_assignments lunch_assignments_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lunch_assignments
    ADD CONSTRAINT lunch_assignments_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES public.shifts(id);


--
-- Name: lunches lunches_lunch_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lunches
    ADD CONSTRAINT lunches_lunch_category_id_fkey FOREIGN KEY (lunch_category_id) REFERENCES public.lunch_categories(id);


--
-- Name: payment_debt_allocations payment_debt_allocations_debt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_debt_allocations
    ADD CONSTRAINT payment_debt_allocations_debt_id_fkey FOREIGN KEY (debt_id) REFERENCES public.enrollment_debts(id);


--
-- Name: payment_debt_allocations payment_debt_allocations_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_debt_allocations
    ADD CONSTRAINT payment_debt_allocations_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: payments payments_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: payments payments_payment_method_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id);


--
-- Name: payments payments_voided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_voided_by_fkey FOREIGN KEY (voided_by) REFERENCES public.users(id);


--
-- Name: person person_address_ubigeo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_address_ubigeo_id_fkey FOREIGN KEY (address_ubigeo_id) REFERENCES public.ubigeo(district_id);


--
-- Name: person person_civil_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_civil_state_id_fkey FOREIGN KEY (civil_state_id) REFERENCES public.civil_state(id);


--
-- Name: person person_document_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_document_type_id_fkey FOREIGN KEY (document_type_id) REFERENCES public.document_types(id);


--
-- Name: person person_ethnic_self_identification_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_ethnic_self_identification_id_fkey FOREIGN KEY (ethnic_self_identification_id) REFERENCES public.ethnic_self_identifications(id);


--
-- Name: person person_gender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_gender_id_fkey FOREIGN KEY (gender_id) REFERENCES public.genders(id);


--
-- Name: person person_native_language_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_native_language_id_fkey FOREIGN KEY (native_language_id) REFERENCES public.languages(id);


--
-- Name: person person_religion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_religion_id_fkey FOREIGN KEY (religion_id) REFERENCES public.religion(id);


--
-- Name: province province_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.province
    ADD CONSTRAINT province_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.department(id);


--
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id);


--
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id);


--
-- Name: school_fee school_fee_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_fee
    ADD CONSTRAINT school_fee_level_id_fkey FOREIGN KEY (level_id) REFERENCES public.levels(id);


--
-- Name: school_fee school_fee_school_fee_concept_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_fee
    ADD CONSTRAINT school_fee_school_fee_concept_id_fkey FOREIGN KEY (school_fee_concept_id) REFERENCES public.school_fee_concepts(id);


--
-- Name: school_fee school_fee_school_year_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_fee
    ADD CONSTRAINT school_fee_school_year_id_fkey FOREIGN KEY (school_year_id) REFERENCES public.school_year(id);


--
-- Name: school_fee school_fee_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_fee
    ADD CONSTRAINT school_fee_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES public.shifts(id);


--
-- Name: school_year_months school_year_months_school_year_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.school_year_months
    ADD CONSTRAINT school_year_months_school_year_id_fkey FOREIGN KEY (school_year_id) REFERENCES public.school_year(id);


--
-- Name: second_languages second_languages_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.second_languages
    ADD CONSTRAINT second_languages_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.person(id);


--
-- Name: second_languages second_languages_second_language_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.second_languages
    ADD CONSTRAINT second_languages_second_language_id_fkey FOREIGN KEY (second_language_id) REFERENCES public.languages(id);


--
-- Name: staff_members staff_members_level_of_education_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_members
    ADD CONSTRAINT staff_members_level_of_education_id_fkey FOREIGN KEY (level_of_education_id) REFERENCES public.level_of_education(id);


--
-- Name: staff_members staff_members_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_members
    ADD CONSTRAINT staff_members_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.person(id);


--
-- Name: enrollment_debts student_debts_charge_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment_debts
    ADD CONSTRAINT student_debts_charge_type_id_fkey FOREIGN KEY (charge_type_id) REFERENCES public.charge_types(id);


--
-- Name: enrollment_debts student_debts_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment_debts
    ADD CONSTRAINT student_debts_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: enrollment_debts student_debts_enrollment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment_debts
    ADD CONSTRAINT student_debts_enrollment_id_fkey FOREIGN KEY (enrollment_id) REFERENCES public.enrollment(id);


--
-- Name: enrollment_debts student_debts_school_year_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment_debts
    ADD CONSTRAINT student_debts_school_year_id_fkey FOREIGN KEY (school_year_id) REFERENCES public.school_year(id);


--
-- Name: enrollment_debts student_debts_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment_debts
    ADD CONSTRAINT student_debts_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.debt_statuses(id);


--
-- Name: enrollment_debts student_debts_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment_debts
    ADD CONSTRAINT student_debts_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(person_id);


--
-- Name: student_homes student_homes_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_homes
    ADD CONSTRAINT student_homes_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(person_id);


--
-- Name: student_school_years student_states_by_year_school_year_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_school_years
    ADD CONSTRAINT student_states_by_year_school_year_id_fkey FOREIGN KEY (school_year_id) REFERENCES public.school_year(id);


--
-- Name: student_school_years student_states_by_year_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_school_years
    ADD CONSTRAINT student_states_by_year_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.student_school_year_states(id);


--
-- Name: student_school_years student_states_by_year_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_school_years
    ADD CONSTRAINT student_states_by_year_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(person_id);


--
-- Name: students students_birth_ubigeo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_birth_ubigeo_id_fkey FOREIGN KEY (birth_ubigeo_id) REFERENCES public.ubigeo(district_id);


--
-- Name: students students_childbirth_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_childbirth_type_id_fkey FOREIGN KEY (childbirth_type_id) REFERENCES public.childbirth_type(id);


--
-- Name: students students_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.person(id);


--
-- Name: ubigeo ubigeo_district_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ubigeo
    ADD CONSTRAINT ubigeo_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.district(id);


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id);


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

\unrestrict 9fOntZCfVe1BKNf8NbYWqAwjzRFhABhEbQxePFGWjdoZtLjCCPCHm10PCyj6kWR

