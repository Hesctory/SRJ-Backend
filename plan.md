# Enrollment & Reenrollment Implementation Plan

## Open questions to resolve first

1. **One endpoint or two?** Plan assumes **two**: `POST /enrollments` (creates student + enrollment) and `POST /reenrollments` (existing student only). Cleaner mapping to React Admin since each is its own `dataProvider` resource with its own form and permission policy.

2. **What happens to `POST /api/students`?** Given the new invariant ("a student can't exist without an enrollment"), this endpoint becomes invalid. Plan: **remove it from the public API** and demote `CreateStudentUseCase` to an internal collaborator called by `EnrollStudentUseCase`.

3. **`Enrollment.Code` format.** The scaffolded model has `Code` (6 chars) and `CodeNumber` (int). Assumed format: zero-padded sequential per school year. Confirm or correct.

4. **Reenrollment uniqueness rule.** Assumed invariant: **one enrollment per student per school year**. Confirm or correct.

5. **Transactions.** Plan uses a lightweight `IUnitOfWork` abstraction in Application, implemented over `DbContext.Database.BeginTransactionAsync()` in Infrastructure.

---

## Domain shift to acknowledge

> **Enrollment becomes the lifecycle event that brings a student into being.**

`CreateStudentUseCase` is no longer a public operation. The aggregate root for the "register a student" flow is now `Enrollment`, which owns the student creation as part of its transaction. This is the move away from CRUD.

---

## Implementation plan

### Phase 1 — Domain layer

**`Domain/Entities/DEnrollment.cs`**
- Fields: `Id`, `Code`, `CodeNumber`, `StudentId`, `GradeOfferingShiftSectionId`, `SchoolFeeConceptId`.
- Constructor enforces non-zero FKs.
- No public setter for `Code`/`CodeNumber` — assigned by a domain service or factory.

**`Domain/Services/IEnrollmentCodeGenerator.cs`** (interface in Domain, impl in Infrastructure)
- `Task<(int number, string code)> NextAsync(int schoolYearId)` — encapsulates the "find max + increment + format" logic. Keeps the format rule in one place.

**`Domain/Services/IStudentEnrollmentPolicy.cs`** (or enforce in use case)
- Decides: "is this student new or returning?" based on enrollment count.
- Enforces the "one per school year" invariant.

### Phase 2 — Application DTOs

```
Application/DTOs/
  Enrollments/
    EnrollmentDataDTO.cs            // shared: gradeOfferingShiftSectionId, schoolFeeConceptId
    EnrollStudentDTO.cs             // CreateStudentDTO fields + EnrollmentDataDTO
    ReenrollStudentDTO.cs           // studentId + EnrollmentDataDTO
    EnrollmentReadDTO.cs            // for GET responses (id, code, student summary, section, fee)
```

Keep these flat — React Admin forms map most cleanly to flat payloads.

### Phase 3 — Application use cases

```
Application/UseCases/Enrollments/
  EnrollStudentUseCase.cs           // student does not exist → creates Person/EducationalPerson/Student/StudentHome/Familiars + Enrollment, all in one transaction
  ReenrollStudentUseCase.cs         // student exists → just creates Enrollment after invariant checks
  GetEnrollmentByIdUseCase.cs
  ListEnrollmentsUseCase.cs         // pagination + sort + filters (React Admin expects these)
```

`EnrollStudentUseCase` internally reuses the existing `CreateStudentUseCase` logic — extract its body into an internal method (or keep it as an injected collaborator) so it isn't duplicated.

Both use cases call `IUnitOfWork.BeginAsync()` → repository writes → commit.

### Phase 4 — Infrastructure

**Repository**
- `IEnrollmentRepository` (match existing convention — Application layer).
- Methods: `CreateAsync`, `GetByIdAsync`, `ListAsync(skip, take, sort, filters)`, `CountAsync(filters)`, `ExistsForStudentInSchoolYearAsync(studentId, schoolYearId)`, `CountByStudentAsync(studentId)`.

**Code generator implementation**
- `EnrollmentCodeGenerator` queries max `CodeNumber` for the year and formats the string.

**Unit of Work**
- `IUnitOfWork` in Application, `EfUnitOfWork` in Infrastructure wrapping `SRJDbContext` transactions.

**Controller — `EnrollmentsController`**

| Method | Route | Use case |
|---|---|---|
| `GET` | `/api/enrollments` | `ListEnrollmentsUseCase` — must set `Content-Range` header |
| `GET` | `/api/enrollments/{id}` | `GetEnrollmentByIdUseCase` |
| `POST` | `/api/enrollments` | `EnrollStudentUseCase` (new student path) |

**Controller — `ReenrollmentsController`**

| Method | Route | Use case |
|---|---|---|
| `POST` | `/api/reenrollments` | `ReenrollStudentUseCase` (existing student path) |

**Authorization policies**: `enrollment.read`, `enrollment.create`, `reenrollment.create`.

### Phase 5 — React Admin compatibility (cross-cutting)

Simple Rest Data Provider expects:

- **Query**: `?_start=0&_end=10&_sort=field&_order=ASC&someFilter=value`
- **Response header**: `Content-Range: enrollments 0-9/123`
- **CORS**: `Access-Control-Expose-Headers: Content-Range` must be set, otherwise the browser strips it.
- **getMany**: `?id=1&id=2&id=3` — the controller has to accept repeated `id` params.

Plan to add a small helper (e.g. `ReactAdminQuery` binding model + a `ContentRange` action result extension) and apply it to the new enrollment list endpoint. Existing list endpoints can be retrofitted later — out of scope for this task.

### Phase 6 — Remove the orphan student creation path

- Delete `POST /api/students` from `StudentsController` (or restrict to an admin-only diagnostic policy).
- Keep `GET /api/students` and detail endpoints — those stay valid.
- Update DI registrations.

---

## Suggested order of execution

1. Confirm the 5 open questions above.
2. Add `IUnitOfWork` + `EnrollmentCodeGenerator` skeletons (foundation).
3. Build `DEnrollment`, repository, and read endpoints (`GET` list + by-id) — gives the frontend something to bind to immediately.
4. Build `EnrollStudentUseCase` + `POST /api/enrollments` (the big one).
5. Build `ReenrollStudentUseCase` + `POST /api/reenrollments`.
6. Remove `POST /api/students`.
7. Add React Admin pagination helper + `Content-Range` header.
