---
name: srj-scaffold
description: >
  Scaffolds new API endpoints and domain components for the SRJBackend project.
  ONLY invoke when the user explicitly types /srj-scaffold. Do NOT auto-trigger
  on words like "scaffold", "add entity", "new endpoint", or any CRUD request.
  Covers Tier 1 (read-only queries + controller) and Tier 2 (simple CRUD with
  DTO-based repositories and use cases). Full domain entities (DXxx with business
  logic) are out of scope.
---

# SRJ Backend Scaffolding

## Manual-Only Guard

This skill must only run when the user has typed `/srj-scaffold`. If you ended up here through a general scaffolding request, stop and confirm: "Did you want to run /srj-scaffold?" before generating anything.

---

## Step 1: Interview

Ask all four questions in a single message. Do not start generating until you have answers to all of them.

1. **Entity name** — singular PascalCase (e.g. `PaymentMethod`, `Subject`, `Religion`)
2. **Tier** — choose one:
   - **Tier 1**: Read-only. Only GET all + GET by id. No writes, no use cases.
   - **Tier 2**: CRUD. DTO-based repository. Operations are selectable (see Q3).
3. **Operations** (Tier 2 only) — which are needed? Present as a checklist:
   - [x] GetAll + GetById (always included)
   - [ ] Create
   - [ ] Update
   - [ ] Delete — ask explicitly; it is often omitted for traceability. Default: not included.
4. **Filters** — Does GetAll need to filter beyond pagination? If yes, list each field name and type (e.g. `name: string`, `levelId: int`). If no, the controller still accepts the `range` query param.

After collecting answers, print a summary and ask the user to confirm before generating.

---

## Step 2: Read the Reference File

Before generating any code, read the relevant reference file:
- Tier 1 → read `references/tier1-readonly.md`
- Tier 2 → read `references/tier2-crud.md`

The reference files contain the actual annotated templates. Generate code by filling in the `Xxx` / `xxx` / `xxxs` placeholders with the entity name (see naming rules below).

---

## Naming Rules

| Concept | Pattern | Example |
|---|---|---|
| Repository interface | `IXxxRepository` | `IPaymentCategoryRepository` |
| Query interface | `IXxxQueries` | `IPaymentCategoryQueries` |
| Use case | `[Verb]XxxUseCase` | `CreatePaymentCategoryUseCase` |
| DTO (read) | `XxxDTO` | `PaymentCategoryDTO` |
| DTO (create/update) | `CreateXxxDTO` | `CreatePaymentCategoryDTO` |
| Filter | `XxxFilter` (no DTO suffix) | `PaymentCategoryFilter` |
| Controller | `XxxsController` (plural) | `PaymentCategoriesController` |
| Route | `"api/xxxs"` lowercase plural | `"api/payment-categories"` |
| Auth policy | `"xxx.action"` kebab-case | `"payment-category.read"` |
| DI extension | `[Domain]ServiceExtensions` | `PaymentServiceExtensions` |

**Namespaces by layer:**
- DTOs: `SRJBackend.Application.DTOs`
- Interfaces: `SRJBackend.Application.Interfaces`
- Use cases: `SRJBackend.Application.UseCases`
- Repositories: `SRJBackend.Infrastructure.Repositories`
- Queries: `SRJBackend.Infrastructure.Queries`
- Controllers: `SRJBackend.Infrastructure.Controllers`
- Extensions: `SRJBackend.Infrastructure.Extensions`

**Pluralization:** append `s` by default. Consonant+y endings → `ies` (Category→Categories, Company→Companies). Endings in s/x/z/ch/sh → `es`.

**Auth policy kebab-case:** convert PascalCase to kebab (`PaymentMethod` → `payment-method`, `SchoolFeeConcept` → `school-fee-concept`).

**JSON serialization:** This project uses ASP.NET Core's default `System.Text.Json` with no custom serializer config. All PascalCase DTO properties serialize to camelCase in responses and are deserialized case-insensitively from request bodies. For example: `LunchCategoryId` → `lunchCategoryId`, `Name` → `name`. The `id` property is already lowercase by convention. No need to check the serializer config — it is always default camelCase.

---

## Step 3: File Generation Order

Generate files one at a time in this order. Verify the file is complete before moving to the next.

**Tier 1:**
1. `Application/DTOs/XxxDTO.cs`
2. `Application/Interfaces/IXxxQueries.cs`
3. `Infrastructure/Queries/XxxQueries.cs`
4. `Infrastructure/Controllers/XxxsController.cs`
5. Update `Infrastructure/Extensions/[Domain]ServiceExtensions.cs`
6. Edit `Infrastructure/Authorization/AuthorizationPoliciesExtension.cs`

**Tier 2:**
1. `Application/DTOs/XxxDTO.cs`
2. `Application/DTOs/CreateXxxDTO.cs`
3. `Application/DTOs/XxxFilter.cs` _(only if filters were requested)_
4. `Application/Interfaces/IXxxRepository.cs`
5. `Application/Interfaces/IXxxQueries.cs`
6. `Infrastructure/Repositories/XxxRepository.cs`
7. `Infrastructure/Queries/XxxQueries.cs`
8. `Application/UseCases/CreateXxxUseCase.cs` _(if Create selected)_
9. `Application/UseCases/UpdateXxxUseCase.cs` _(if Update selected)_
10. `Application/UseCases/DeleteXxxUseCase.cs` _(if Delete selected)_
11. `Infrastructure/Controllers/XxxsController.cs`
12. Update `Infrastructure/Extensions/[Domain]ServiceExtensions.cs`
13. Edit `Infrastructure/Authorization/AuthorizationPoliciesExtension.cs`

---

## Controller Response Conventions

These must be exact — do not deviate.

**GET list:**
```csharp
int start = 0, take = int.MaxValue;
if (range != null)
{
    var bounds = JsonSerializer.Deserialize<int[]>(range)!;
    if (bounds == null || bounds.Length != 2) return BadRequest("Invalid range");
    start = bounds[0];
    take = bounds[1] - start + 1;
}
var (items, total) = await _xxxQueries.GetPagedAsync(start, take, filters);
var rangeEnd = total == 0 ? 0 : start + items.Count - 1;
Response.Headers.Append("Content-Range", $"xxxs {start}-{rangeEnd}/{total}");
return Ok(items);
```
Note: `xxxs` in the Content-Range header is the lowercase plural entity name.

**GET by id:** `return item == null ? NotFound() : Ok(item);`

**POST:** `return CreatedAtAction(nameof(GetById), new { id }, new { id });`

**PUT:** call use case, then re-fetch: `var updated = await _xxxQueries.GetByIdAsync(id); return Ok(updated);`

**DELETE:** `if (!deleted) return NotFound(); return NoContent();`

---

## DI Extension Update

After generating all files, provide the DI snippet to add to the relevant `Infrastructure/Extensions/[Domain]ServiceExtensions.cs`. If the entity doesn't clearly belong to an existing extension file, **ask the user** which file to add it to (or whether to create a new one).

Registration order: repository → queries → use cases (all `AddScoped`).

Never add `IUnitOfWork` in Tier 1 or Tier 2 — it is only for full domain tiers.

```csharp
// Tier 1 snippet:
services.AddScoped<IXxxQueries, XxxQueries>();

// Tier 2 snippet (include only registered use cases):
services.AddScoped<IXxxRepository, XxxRepository>();
services.AddScoped<IXxxQueries, XxxQueries>();
services.AddScoped<CreateXxxUseCase>();    // if Create
services.AddScoped<UpdateXxxUseCase>();    // if Update
services.AddScoped<DeleteXxxUseCase>();    // if Delete
```

---

## Auth Policy Registration

After the DI extension update, directly edit `Infrastructure/Authorization/AuthorizationPoliciesExtension.cs`. Read the file first, then append the new policies inside the `services.AddAuthorization(options => { ... })` block, just before the closing `});`. Only include the policies for operations that were selected.

```csharp
options.AddPolicy("xxx.read", policy =>
    policy.Requirements.Add(new PermissionRequirement("xxx.read")));
options.AddPolicy("xxx.create", policy =>       // if Create
    policy.Requirements.Add(new PermissionRequirement("xxx.create")));
options.AddPolicy("xxx.update", policy =>       // if Update
    policy.Requirements.Add(new PermissionRequirement("xxx.update")));
options.AddPolicy("xxx.delete", policy =>       // if Delete
    policy.Requirements.Add(new PermissionRequirement("xxx.delete")));
```

After editing, run `dotnet build` to confirm everything compiles.

---

## Optional: Frontend Reference File

After the auth policy block, ask the user:

> "Do you want a `<entityname>.txt` file at the project root with the expected JSON shapes and recommended TypeScript types for the frontend?"

If yes, generate a plain-text file at the project root named after the primary entity (e.g., `lunch.txt`, `payment-method.txt`). The file must cover every endpoint generated in this run and include:

1. **Endpoint list** — method, path, query params, request body (if any), response body shape, notable response codes.
2. **JSON examples** — one concrete example per DTO, using camelCase keys (per the serializer note above). Mark nullable fields explicitly.
3. **TypeScript types** — one `interface` per DTO (`XxxDTO` for reads, `CreateXxxPayload` for writes). Use `number | null` / `string | null` for nullable fields, not `?` optional — the backend always includes the key.
4. **Pagination helpers** — include `parseTotalFromContentRange` and `buildRangeParam` utility functions once, even if multiple entities were scaffolded.
5. **Auth policies** — list the policy strings that were registered so the frontend team knows what permissions to request.

If no → skip silently.
