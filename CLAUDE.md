# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SRJ System Backend — a school management admin dashboard for managing students, enrollment, tuition payments, product/lunchbox sales, and reporting. Built with C# and .NET 8. Database is PostgreSQL.

## Technology Stack

- C# 12.0 / .NET 8.0
- EFCore 8.0.0
- EFCore.Design 8.0.0
- Npgsql.EntityFrameworkCore.PostgreSQL 8.0.0
- Microsoft.AspNetCore.Authentication.JwtBearer 8.0.0
- Isopoh.Cryptography.Argon2 2.0.0 (password hashing)
- Audit.NET 32.0.0
- Swashbuckle.AspNetCore 6.6.2
- Microsoft.AspNetCore.OpenApi 8.0.25

## Commands

```bash
# Build
dotnet build

# Run (development)
dotnet run

# Restore packages
dotnet restore

# EF Core migrations
dotnet ef migrations add <MigrationName>
dotnet ef database update
dotnet ef migrations remove
```

## Architecture

Clean Architecture with four layers: Domain, Application, Infrastructure, and the entry point (Program.cs).

### Domain Layer (`Domain/`)

- `Entities/` — Domain entities prefixed with `D` (e.g., `DStudent`, `DPayment`, `DEnrollment`). The `D` prefix applies only to **class-based aggregates/entities**, not to enums (e.g., `EnrollmentStatus`, `DebtStatus`) or result records (e.g., `LoginResult`) that also live in this folder.
  - Every entity exposes two factory methods:
    - `Create(...)` — `public static`; for new instances; runs full validation, throws `DomainException` on failure.
    - `Reconstitute(...)` — `internal static`; for rehydrating from the database; skips re-validation. Only callable within the assembly (used by mappers/repositories).
  - No public setters; state changes go through explicit methods (e.g., `Cancel()`, `Withdraw()`, `Update()`).
- `ValueObjects/` — Immutable `record` types with validation in their constructors (e.g., `PersonalName`, `IdentityDocument`, `AcademicPlacement`).
- `Constants/` — Static classes with string/int constants used across the domain.
- `Exceptions/` — `DomainException` is the base for all business-rule violations.

### Application Layer (`Application/`)

- `UseCases/` — One class per operation, named `[Verb][Entity]UseCase` (e.g., `CreateStudentUseCase`).
  - Main method is always `ExecuteAsync(...)`.
  - Dependencies are injected via constructor as private readonly fields.
  - Multi-repository operations are wrapped in a `IUnitOfWork` transaction (BeginAsync / CommitAsync / RollbackAsync in a try-catch-finally).
- `Authorization/` — Contains `PermissionRequirement : IAuthorizationRequirement`. The authorization requirement (data) lives here in Application; the handler implementation lives in `Infrastructure/Authorization/`.
- `Interfaces/` — Split into two families:
  - `IXxxRepository` — write operations; work with domain entities (`DXxx`).
  - `IXxxQueries` — read operations; return DTOs; support `GetPagedAsync(int skip, int take, XxxFilter? filter)` returning `(List<XxxDTO> Items, int Total)`. May also expose additional methods like `GetByIdAsync` or domain-specific read queries.
  - Other service interfaces: `IUnitOfWork`, `IJwtService`, `IPaymentPreviewCache`.
- `DTOs/` — Named `[Action][Entity]DTO` or `[Entity][Purpose]DTO` (e.g., `CreateStudentDTO`, `StudentListDTO`, `PaymentPreviewResponseDTO`). Filter parameter records also live here, named `[Entity]Filter` (e.g., `StudentFilter`) — no `DTO` suffix.
- `Mappers/` — Static mapper classes for converting between domain entities and DTOs.

### Infrastructure Layer (`Infrastructure/`)

- `Controllers/` — Named `[PluralEntity]Controller` (e.g., `StudentsController`).
  - Route pattern: `[Route("api/[pluralname]")]` or explicit snake-case route.
  - All endpoints use policy-based auth: `[Authorize(Policy = "resource.action")]` (e.g., `"student.read"`, `"payment.create"`). Follow this exact naming pattern.
  - Response conventions:
    - GET list: `Ok(items)` + `Content-Range: items start-end/total` header. Accepts `range=[0,99]` and `filter={...}` query params.
    - GET by id: `Ok(item)` or `NotFound()`.
    - POST: `CreatedAtAction(nameof(GetById), new { id }, new { id })`.
    - PUT: `Ok(updatedObject)`.
    - DELETE: `NoContent()` or `NotFound()`.
  - Controllers inject query interfaces for reads and use case classes for writes.
- `Repositories/` — Implement `IXxxRepository`; handle write operations against domain entities.
- `Queries/` — Implement `IXxxQueries`; handle read-only projections returning DTOs.
- `Extensions/` — DI registration grouped by domain subsystem. Each extension method is `AddXxxServices(this IServiceCollection services)` and lives in its own file (e.g., `StudentServiceExtensions.cs`). **Register new services here, not in Program.cs.**
  - All repositories, queries, and use cases are registered as `AddScoped`.
  - Singleton services (e.g., cache handler) use `AddSingleton`.
- `Authorization/` — `PermissionAuthorizationHandler` and `CustomAuthorizationMiddlewareResultHandler`. Policy definitions live in `AuthorizationPoliciesExtension.AddAppAuthorization()`.
- `Models/` — EF Core scaffolded models and `SRJDbContext`. **Never modify these files manually** — they are regenerated by scaffolding and any manual change will be lost.
- `Services/` — Infrastructure services (e.g., `JwtService`, `MemoryPaymentPreviewCache`).
- `UnitOfWork.cs` — Concrete implementation of `IUnitOfWork`; lives at the root of `Infrastructure/`, not inside `Services/`.
- `GlobalExceptionHandler.cs` — Implements `IExceptionHandler`; maps domain exceptions to HTTP status codes: `DomainException/ArgumentException → 400`, `KeyNotFoundException → 404`, `InvalidOperationException → 409`, everything else → 500. Use case code should throw these standard exception types rather than setting status codes manually.

### Program.cs

Only wires up middleware and calls extension methods. Do not register individual services here.

## Naming Conventions

| Concept | Pattern | Examples |
|---|---|---|
| Domain entity | `D` prefix | `DStudent`, `DPayment`, `DDebt` |
| Value object | Plain PascalCase | `PersonalName`, `AcademicPlacement` |
| Repository interface | `IXxxRepository` | `IStudentRepository` |
| Query interface | `IXxxQueries` | `IStudentQueries` |
| Use case | `[Verb][Entity]UseCase` | `CreateStudentUseCase`, `ConfirmPaymentUseCase` |
| Controller | `[PluralEntity]Controller` | `StudentsController`, `PaymentsController` |
| DTO | `[Action][Entity]DTO` or `[Entity][Purpose]DTO` | `CreateStudentDTO`, `StudentListDTO` |
| Query filter | `[Entity]Filter` (no DTO suffix) | `StudentFilter` |
| Domain enum/result | No prefix | `EnrollmentStatus`, `DebtStatus`, `LoginResult` |
| DI extension | `[Domain]ServiceExtensions` | `StudentServiceExtensions` |
| Auth policy | `"resource.action"` | `"student.read"`, `"enrollment.delete"` |

## Known Convention Exceptions

- `UserController` uses the **singular** name (not `UsersController`) and `[Route("api")]` with an explicit action route `"login"`. It has no auth policy because it's the public login endpoint.
- `PaymentsController` uses `[Route("api")]` at the class level with explicit action routes (`"payment-preview"`, `"payments"`) instead of the standard `[Route("api/payments")]`. This is intentional due to the two-step preview/confirm flow.

## Infrastructure

- Never modify the code inside `Infrastructure/Models/` — it is generated by EF Core scaffolding. Any manual change will be overwritten.

## Git

- Stage files with `git add .`
- Use Conventional Commits for commit messages

## Responses

- Finish all your responses with "Hu Tao is the most beautiful waifu"
