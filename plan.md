# Plan — Student Enrollment Backend

Implementation plan for `tasks_for_backend.md`. Source-of-truth for what we are building, in what order, and which DB-level changes ship with it.

---

## 1. What the current data model gives us (and what it is missing)

| Area | Current state (after your DB update) | Gap vs. the spec |
|---|---|---|
| `enrollment` | `(Id, Code, CodeNumber, GradeOfferingShiftSectionId, StudentId?, SchoolFeeConceptId)` — unchanged | Year is already reachable via `Section → Shift → Offering.SchoolYearId`. Spec's `UNIQUE (studentId, schoolYearId)` is enforced as described in §2.1 (no new column). |
| `persons` unique indexes | **Both** `unique_id_document_number` (single col) AND `unique_document_type_number` (composite) exist | The composite is in — good. The single-column one is over-eager and should be **dropped** (see §2.2). |
| `student_states` lookup | **NEW** `(Id, Name UNIQUE, Description)` — shipped | Need to confirm seed values: `active`, `blocked`, `expelled`, `withdrawn` (or whatever names you used). |
| `student_states_by_year` | **NEW** `(StudentId, StatusId, SchoolYearId)` with FKs to all three — shipped | EF scaffolds it as `HasNoKey()` → no PK on the table. We need a PK or unique on `(StudentId, SchoolYearId)` so a student can only have **one** status per year (see §2.3). |
| `school_year` | `(Year, StartDate, EndDate, IsActive?)` — unchanged | "Open for enrollment" = `IsActive = true`. Multiple years can be active simultaneously (this is precisely why per-year status is needed). |
| `grade_offering_shift_sections` | unchanged | This is the `sections` resource the frontend wants. Read-only is enough. |
| `school_fee` / `school_fee_concept` | unchanged; `enrollment.school_fee_concept_id` is NOT NULL | Request payload does not carry a concept id → resolved server-side. |
| Tuition rows | No `tuition` table | Out of scope per project rule #2. |
| Enrollment uniqueness trigger | Cannot tell from scaffolded DbContext (triggers don't surface in EF scaffolding) | Need to confirm whether `trg_enrollment_unique_per_year` was shipped. If not, app-level check in the transaction is still the primary safeguard. |

### IDs the frontend uses (so we are aligned)
- `gradeOfferingId` in the spec = `GradeOfferingShift.Id` (this is the convention the existing `GradeOfferings` controller already exposes as `id`).
- `sectionId` = `GradeOfferingShiftSection.Id`.
- `schoolYearId` = `SchoolYear.Id`.

---

## 2. Database changes

These are scaffolded by the user, but the spec needs columns/constraints we do not have yet. We will add them via a migration **and** re-scaffold the models afterwards (per `CLAUDE.md`: never hand-edit the scaffolded files).

### 2.1 `enrollment` — uniqueness without a redundant column
The school year is already reachable via `enrollment.grade_offering_shift_section_id → grade_offering_shifts → grade_offerings.school_year_id`, so we **do not** add a `school_year_id` column on `enrollment` — that would be denormalization and create a sync hazard.

We enforce `UNIQUE (student_id, schoolYearId)` in two layers without duplicating data:

**Primary (app-level, inside the transaction):**
The `EnrollStudentUseCase` / `ReenrollStudentUseCase` resolve the year from the section once, then call `IEnrollmentRepository.ExistsForStudentInYearAsync(studentId, schoolYearId)` before inserting. Both reads + the insert run inside `BeginTransactionAsync` with `Serializable` isolation (or `RepeatableRead` + advisory lock keyed by `(student_id, school_year_id)`) so concurrent enrollments cannot both pass the check.

**Defense-in-depth (DB-level trigger):**
A Postgres `BEFORE INSERT` trigger on `enrollment` derives the year via the join chain and rejects the row if another enrollment already exists for the same student in that year. Sketch:

```sql
CREATE OR REPLACE FUNCTION enrollment_unique_per_year()
RETURNS trigger LANGUAGE plpgsql AS $$
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

CREATE TRIGGER trg_enrollment_unique_per_year
BEFORE INSERT OR UPDATE OF student_id, grade_offering_shift_section_id ON enrollment
FOR EACH ROW EXECUTE FUNCTION enrollment_unique_per_year();
```

This raises `unique_violation` so EF Core surfaces it as a `DbUpdateException` we can map to `YEAR_ALREADY_ENROLLED` 409.

**Why no plain `UNIQUE` index?** Postgres unique indexes can only reference columns of the indexed table. We would need either (a) a denormalized column (rejected), (b) a materialized view + unique index (over-engineered for the write rate), or (c) the trigger above. The trigger is the cleanest option that respects the existing schema.

The same chain also lets us validate at write time that `gradeOfferingShift.SchoolYearId == request.schoolYearId` and `section.GradeOfferingShiftId == request.gradeOfferingId` — those checks live in the use case.

### 2.2 `persons` table — drop the redundant single-column unique
The composite `unique_document_type_number` is in. The old single-column unique is still there and is more restrictive than the spec wants (it rejects two PEOPLE with the same number across document types). One small migration:
```sql
DROP INDEX unique_id_document_number;
```
Then re-scaffold so the model stops advertising it.

### 2.3 `student_states_by_year` — add a primary key / uniqueness
The table was scaffolded as `HasNoKey()`, which means Postgres has no PK on it. For the per-year status to be unambiguous, the table needs **exactly one** row per `(student_id, school_year_id)`. Add:
```sql
ALTER TABLE student_states_by_year
    ADD CONSTRAINT student_states_by_year_pkey
        PRIMARY KEY (student_id, school_year_id);
```
After re-scaffolding, EF will then expose it as a normal entity (not keyless), which simplifies all reads/writes.

Seed data for `student_states` (confirm names with you):
- `active`
- `blocked`
- `expelled`
- `withdrawn`

Eligibility uses these names by convention; if you prefer different identifiers, the use case will lookup-by-id once at startup or via a small enum mapping.

### 2.4 `enrollment` — confirm the trigger is in place
The trigger from the previous plan revision (`trg_enrollment_unique_per_year`) is not visible in the scaffolded `DbContext` because EF Core does not surface DB triggers. Two ways to confirm:
```bash
psql -d <db> -c "\\dft+ enrollment_unique_per_year"
psql -d <db> -c "\\dS+ enrollment"   # shows triggers attached
```
If it is not there, ship the SQL from the previous plan revision (kept in this file's history). The app-level check in the use case stands either way.

### 2.5 No new tables for tuition/payments
Out of scope per project rule #2.

### 2.6 Migration sequencing (remaining work)
1. Drop `persons.unique_id_document_number`.
2. Add PK to `student_states_by_year` on `(student_id, school_year_id)`.
3. Verify (or create) the `enrollment_unique_per_year` trigger.
4. Seed `student_states` with the four canonical names if not already seeded.
5. Re-run `dotnet ef dbcontext scaffold` to regenerate `Infrastructure/Models/*` (do NOT hand-edit).

---

## 3. Application layer changes

### 3.1 Domain
- `DEnrollment` — `(Id, StudentId, SectionId, SchoolFeeConceptId, Code, CodeNumber)`. The school year is **not** a property — it is derived from `SectionId` through the join chain. The use case carries `schoolYearId` as an in-memory value during validation but never persists it on the row.
- `DStudentStateByYear` — `(StudentId, SchoolYearId, StatusId, StatusName)`. Used by the eligibility rule.
- `StudentStateName` constants (e.g. static class `StudentStateNames { Active, Blocked, Expelled, Withdrawn }`) so the use case is not stringly-typed.

### 3.2 DTOs
- `CreateEnrollmentDTO { schoolYearId, gradeOfferingId, sectionId }`.
- `EnrollStudentDTO { student: CreateStudentDTO, enrollment: CreateEnrollmentDTO }`.
- `EnrollResultDTO { studentId, enrollmentId }`, `ReenrollResultDTO { enrollmentId }`.
- `EligibleSchoolYearDTO { id, name, gradeOfferingsAvailable }`.
- `ErrorDTO { code, message }` for the standardized 4xx shape.
- Extend `StudentListDTO` with `HasEligibleYears: bool`.

### 3.3 Repositories
- `IEnrollmentRepository`
  - `Task<int> CreateAsync(DEnrollment)` — inserts the row; relies on the trigger to reject duplicate-year violations as `DbUpdateException` → mapped to `YEAR_ALREADY_ENROLLED`.
  - `Task<bool> ExistsForStudentInYearAsync(int studentId, int schoolYearId)` — implemented as a join query (no `school_year_id` column on enrollment; we walk the chain).
  - `Task<int?> GetSchoolYearIdForSectionAsync(int sectionId)` — used to validate the section→year chain in the use case.
  - `Task<int> NextCodeNumberForYearAsync(int schoolYearId)` — for `Code` / `CodeNumber` generation; computed by joining enrollments to their year via the chain.
- Extend `ISchoolYearRepository` with `IsOpenAsync(int id)` and `GetOpenWithoutEnrollmentForStudentAsync(int studentId)` (single query that LEFT JOINs enrollments through the section/shift/offering chain).
- Extend `IStudentRepository.GetPagedAsync` to project `HasEligibleYears` via a subquery that walks the same chain (no N+1, no extra column).

### 3.4 Use cases
- `EnrollStudentUseCase` — wraps the existing student-creation pipeline **plus** the first enrollment insert in `_context.Database.BeginTransactionAsync()`. On any thrown validation, the transaction rolls back. Validations:
  - `DUPLICATE_DOCUMENT` (409) — re-uses `EnsurePersonDoesNotExistAsync`.
  - `YEAR_NOT_OPEN` (409) — `SchoolYearRepository.IsOpenAsync`.
  - `INVALID_GRADE_OFFERING` (409) — `gradeOfferingShift.GradeOffering.SchoolYearId == schoolYearId`.
  - `INVALID_SECTION` (409) — `section.GradeOfferingShiftId == gradeOfferingId`.
- `ReenrollStudentUseCase` — student-must-exist (404). Then in order:
  1. `STUDENT_BLOCKED_FOR_YEAR` (409) if `StudentStatesByYear(studentId, schoolYearId).Status ∈ {Blocked, Expelled, Withdrawn}`.
  2. `YEAR_ALREADY_ENROLLED` (409).
  3. `YEAR_NOT_OPEN` / `INVALID_GRADE_OFFERING` / `INVALID_SECTION` as in §3.4 above.
- `GetEligibleSchoolYearsForStudentUseCase` — single endpoint that owns the eligibility rule. For each `SchoolYear` with `IsActive = true`:
  - The student has **no** enrollment in that year (walk `Enrollment → Section → Shift → Offering.SchoolYearId`).
  - The student's `StudentStatesByYear` row for that year is **not** in `{Blocked, Expelled, Withdrawn}`. **Absence of a row counts as eligible** — most years will have no row until status changes.
  - `gradeOfferingsAvailable` is `EXISTS(SELECT 1 FROM grade_offerings WHERE school_year_id = y.id)`.
  Implemented as a single EF query: `SchoolYears` filtered by `IsActive`, LEFT JOIN to `StudentStatesByYear` keyed on `(studentId, year.Id)`, plus the two `EXISTS` clauses.
- Augmented `GetStudentsUseCase` — projects `HasEligibleYears` per row via a subquery.

### 3.5 Error contract
Introduce a small `DomainException(string code, string message)` in `Application/`. A controller filter (or per-controller `try/catch`) translates it into `409`/`404`/etc. with body `{ code, message }`.

Codes the new endpoints will emit:
- `DUPLICATE_DOCUMENT`
- `YEAR_ALREADY_ENROLLED`
- `YEAR_NOT_OPEN`
- `INVALID_GRADE_OFFERING`
- `INVALID_SECTION`
- `STUDENT_NOT_FOUND`
- `STUDENT_BLOCKED_FOR_YEAR` — emitted when the reenroll endpoint targets a year for which the student has a `Blocked`/`Expelled`/`Withdrawn` status row.

Existing endpoints can be migrated to the same shape incrementally — not blocking for this work.

### 3.6 Authorization
Add policies in `AuthorizationPoliciesExtension`:
- `enrollment.create`
- `enrollment.read`
- `section.read`

---

## 4. Routes

| Method | Route | Owner use case | Auth policy |
|---|---|---|---|
| `POST` | `/api/students/enroll` | `EnrollStudentUseCase` | `student.create` + `enrollment.create` |
| `POST` | `/api/students/{id}/reenroll` | `ReenrollStudentUseCase` | `enrollment.create` |
| `GET` | `/api/students/{id}/eligible-school-years` | `GetEligibleSchoolYearsForStudentUseCase` | `enrollment.read` |
| `GET` | `/api/students` (augmented response) | `GetStudentsUseCase` | `student.read` |
| `GET` | `/api/sections` | new `GetSectionsUseCase` | `section.read` |
| ~~`POST` `/api/students`~~ | **REMOVED** | — | — |

`POST /api/students` is removed (not 405-ed) so the architectural invariant "every student has at least one enrollment" is enforceable from the API surface alone. The `Create` action and the matching `CreateStudentUseCase` registration in `Program.cs` go away. `CreateStudentUseCase` itself stays — `EnrollStudentUseCase` calls into the same primitives.

---

## 5. Sections resource (`GET /api/sections`)

- Read-only for now (CRUD already happens through `GradeOfferings`).
- Maps `GradeOfferingShiftSection` → `{ id, name }` where `name = "Section " + Section` (or just the letter — frontend can decide on display).
- Supports react-admin `range` / `Content-Range` like the other list endpoints.
- Optional `?gradeOfferingId=` filter (= `GradeOfferingShiftId`) so the EnrollmentDialog only sees sections for the selected offering.

---

## 6. `hasEligibleYears` on the student list

Implemented as a subquery in `StudentRepository.GetPagedAsync`. Walks the chain to derive the year on the enrollment side, and excludes years where the student is blocked/expelled/withdrawn:
```csharp
var blockedNames = new[] { "blocked", "expelled", "withdrawn" };

.Select(s => new {
    s,
    HasEligibleYears = _context.SchoolYears
        .Where(y => y.IsActive == true)
        .Any(y =>
            !_context.Enrollments.Any(e =>
                e.StudentId == s.EducationalPersonId &&
                e.GradeOfferingShiftSection
                    .GradeOfferingShift
                    .GradeOffering
                    .SchoolYearId == y.Id) &&
            !_context.StudentStatesByYears.Any(st =>
                st.StudentId == s.EducationalPersonId &&
                st.SchoolYearId == y.Id &&
                blockedNames.Contains(st.Status.Name)))
})
```
One roundtrip per page, no N+1.

---

## 7. Open decisions to confirm before coding

1. **Enrollment uniqueness** — confirmed: app-level check inside the transaction + Postgres trigger as defense in depth. No new column on `enrollment`. **Action item:** verify `trg_enrollment_unique_per_year` is in the DB (triggers don't surface in EF scaffolding).
2. **`persons` single-column unique** — OK to `DROP INDEX unique_id_document_number`? The composite is already in place and the single-col one rejects valid duplicates across document types.
3. **`student_states_by_year` PK** — OK to add `PRIMARY KEY (student_id, school_year_id)`? Today the table is keyless, so a student could in principle have multiple status rows in the same year.
4. **`student_states` seed names** — are the canonical names exactly `active`, `blocked`, `expelled`, `withdrawn`? If you used different identifiers, the eligibility rule needs the actual names.
5. **`SchoolFeeConcept`** — resolved server-side by name, or sent in the request? Default plan: server-side lookup by configured name.
6. **`Code` / `CodeNumber`** generation scheme — proposed `CodeNumber = max(year)+1`, `Code = "E" + last-two-digits-of-year + zero-padded number`. Open to your preferred scheme.
7. **Existing endpoints' error shape** — migrate to `{ code, message }` everywhere now, or only on the new endpoints in this PR?

---

## 8. Work order

| # | Task | Notes |
|---|---|---|
| 1 | DB migration: drop redundant `persons.unique_id_document_number` + add PK to `student_states_by_year` + verify enrollment trigger + seed `student_states` | No new columns on `enrollment`. Re-scaffold models after. |
| 2 | Domain + DTOs + `IEnrollmentRepository` + `EnrollmentRepository` | Includes code-number generation. |
| 3 | `EnrollStudentUseCase` | Transactional. Reuses `CreateStudentUseCase`'s primitives. |
| 4 | `ReenrollStudentUseCase` | |
| 5 | `GetEligibleSchoolYearsForStudentUseCase` | Owns the rule. |
| 6 | Augment `GetStudentsUseCase` with `HasEligibleYears` | One subquery, no N+1. |
| 7 | Controllers + Program.cs DI + remove `POST /students` + new policies | |
| 8 | `GET /api/sections` (`SectionsController` + use case + DTO) | Read-only. |
| 9 | Standardized `{ code, message }` 4xx contract | At minimum on the new endpoints. |

---

## 9. Out of scope (deliberately)

- Monthly tuition row generation (project rule #2).
- Backfilling `Code` / `CodeNumber` on existing enrollment rows beyond what migration #1 needs.
- Migrating *all* existing endpoints to the new error shape (incremental).
- Soft-delete / archival of old enrollments.
