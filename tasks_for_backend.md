# Backend Tasks — Student Enrollment

These are the work items the backend team needs to own so the frontend implementation of the Student Enrollment plan works end-to-end. Grouped by endpoint and concern.

---

## 1. New endpoint: `POST /students/enroll`

**Contract:**
```jsonc
// Request
{ "student": { /* full student payload */ }, "enrollment": { "schoolYearId": 1, "gradeOfferingId": 12, "sectionId": 3 } }
// 201
{ "studentId": 42, "enrollmentId": 88 }
// 409
{ "code": "DUPLICATE_DOCUMENT" | "YEAR_ALREADY_ENROLLED", "message": "..." }
```

**Backend responsibilities:**
- Wrap student insert + first enrollment insert in a **single DB transaction** — roll back both on any failure.
- Validate document uniqueness (`idDocumentNumber` + `documentTypeId`) → 409 `DUPLICATE_DOCUMENT`.
- Validate the requested `schoolYearId` is currently open for enrollment → 409 (new code, e.g. `YEAR_NOT_OPEN`).
- Validate `gradeOfferingId` belongs to that `schoolYearId`.
- Validate `sectionId` belongs to that `gradeOfferingId`.
- Cascade-insert child collections that ride on the student payload: `familiars[]`, disability info, addresses, second languages, etc.
- Trigger any derived rows that downstream features depend on — most importantly, **generate the monthly tuition rows** for the new enrollment (the existing `EnrollmentPaymentsEdit` UI assumes they exist).

---

## 2. New endpoint: `POST /students/:id/reenroll`

**Contract:**
```jsonc
// Request: enrollment payload only
{ "schoolYearId": 2, "gradeOfferingId": 14, "sectionId": 5 }
// 201: { "enrollmentId": 91 }
// 409 if (studentId, schoolYearId) already exists
```

**Backend responsibilities:**
- Validate student exists (404 otherwise).
- Enforce DB-level **unique `(studentId, schoolYearId)`** in the enrollments table → return 409 `YEAR_ALREADY_ENROLLED`.
- Same year-open and FK validations as the enroll endpoint.
- Same tuition-row generation side effect.

---

## 3. New endpoint: `GET /students/:id/eligible-school-years`

**Contract:**
```jsonc
[ { "id": 2, "name": "2026", "gradeOfferingsAvailable": true } ]
```

**Backend responsibilities (this is the load-bearing one):**
- **Owns the eligibility rule.** The frontend never recomputes it — it just renders what's returned.
- Return school years where **all** of:
  - The year is in the open-for-enrollment window.
  - The student has **no row** in `enrollments` for that year.
  - The student's status is not blocked/expelled/withdrawn.
- For each year, set `gradeOfferingsAvailable = true` only if there is at least one valid grade-offering the student can be placed into for that year.
- Return `[]` (empty array) when nothing matches — the Reenroll button uses this to disable itself.

---

## 4. Augmentation: `GET /students` list response

To avoid N per-row API calls when rendering the list, expose one additional field per row:
- `hasEligibleYears: boolean` (or `eligibleYearsCount: number`).

The frontend will use this to decide the enabled state of the per-row Reenroll button without fetching for each one. The per-student endpoint above is then only hit when the dialog opens.

---

## 5. `POST /students` should be removed (or locked down)

The frontend no longer calls it. The backend should either:
- Drop the route entirely, or
- Return 405/403 so any rogue caller (Postman, scripts, an old client) cannot create an orphan student outside the composite flow.

This is the only way the architectural invariant ("every student has at least one enrollment") is enforceable end-to-end.

---

## 6. `sections` resource endpoints

The frontend now consumes `<ReferenceInput reference="sections">` inside the EnrollmentDialog. Backend needs `GET /sections` (and the rest of CRUD if not already shipped) returning `{ id, name, ... }`.

---

## 7. Error contract conventions

Frontend already special-cases two codes in `EnrollmentDialog.tsx`:
- `DUPLICATE_DOCUMENT`
- `YEAR_ALREADY_ENROLLED`

Backend should standardize **all** 4xx responses on the same shape — `{ code, message }` — and add codes for the other failure modes (`YEAR_NOT_OPEN`, `INVALID_GRADE_OFFERING`, `SECTION_FULL`, `STUDENT_BLOCKED`, etc.) so the frontend can localize them without parsing `message`.

---

## 8. Database constraints (defense in depth)

Even though the API enforces these, add DB-level constraints so concurrent requests can't slip through:
- `UNIQUE (studentId, schoolYearId)` on `enrollments`.
- `UNIQUE (documentTypeId, idDocumentNumber)` on `students`.
- Foreign keys from `enrollments.gradeOfferingId` → matching `schoolYearId`, and `enrollments.sectionId` → matching `gradeOfferingId`.

---

## Summary of ownership

| Concern | Owner |
|---|---|
| Atomic create of student + first enrollment | **Backend** (single transaction) |
| Reenrollment uniqueness per year | **Backend** (DB constraint + 409) |
| Eligibility rule (open year, not already enrolled, not blocked) | **Backend** (single endpoint) |
| Tuition row generation on enrollment | **Backend** (side effect) |
| Preventing orphan students | **Backend** (remove `POST /students`) |
| Error code taxonomy | **Backend** (standardize `{ code, message }`) |

The frontend's job is reduced to: collect form data, fire the right composite request, render the response.
