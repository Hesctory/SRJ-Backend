# Tier 2: Simple CRUD Templates

These templates mirror the `GradesController` / `GradeRepository` / `GradeQueries` pattern.
Replace `Xxx` with PascalCase entity name, `xxx` with lowercase, `xxxs` with lowercase plural.

---

## XxxDTO.cs

```csharp
namespace SRJBackend.Application.DTOs;

public class XxxDTO
{
    public int id { get; set; }          // lowercase 'id' — matches frontend convention
    // TODO: add properties
    public string Name { get; set; } = null!;
}
```

---

## CreateXxxDTO.cs

```csharp
namespace SRJBackend.Application.DTOs;

public class CreateXxxDTO
{
    // TODO: add properties (no id — it is assigned by the database)
    public string Name { get; set; } = null!;
}
```

> If the update payload is identical to the create payload (which is the case for most simple entities in this project — Grade, Level, SchoolFeeConcept), reuse `CreateXxxDTO` for both Create and Update. Only generate a separate `UpdateXxxDTO` if the user explicitly says the payloads differ.

---

## XxxFilter.cs (only if filters were requested)

```csharp
namespace SRJBackend.Application.DTOs;

public record XxxFilter(
    // TODO: add nullable filter fields. Example:
    string? Name = null,
    int? RelatedId = null
);
```

> Note: if not using a typed filter record, the queries use `Dictionary<string, JsonElement>` instead — which is the default for Tier 2 (matches GradeQueries pattern). Only use the typed record approach when the filter has many fields or complex logic.

---

## IXxxRepository.cs

```csharp
using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IXxxRepository
{
    Task<bool> ExistsAsync(int id);
    Task<int> CreateAsync(CreateXxxDTO dto);      // include only if Create was requested
    Task UpdateAsync(int id, CreateXxxDTO dto);   // include only if Update was requested
    Task<bool> DeleteAsync(int id);               // include only if Delete was requested
}
```

> Only include the methods that correspond to the operations the user selected. Do not add unused methods.

---

## IXxxQueries.cs

```csharp
using System.Text.Json;
using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IXxxQueries
{
    Task<(List<XxxDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null);
    Task<XxxDTO?> GetByIdAsync(int id);
}
```

---

## XxxRepository.cs

```csharp
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class XxxRepository : IXxxRepository
{
    private readonly SRJDbContext _context;

    public XxxRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        return await _context.Xxxs.AnyAsync(x => x.Id == id); // TODO: verify DbSet name matches EF scaffolded model
    }

    // Include CreateAsync only if Create was requested:
    public async Task<int> CreateAsync(CreateXxxDTO dto)
    {
        var entity = new Xxx   // TODO: verify EF model class name
        {
            // TODO: map dto properties to EF model fields
        };
        _context.Xxxs.Add(entity);
        await _context.SaveChangesAsync();
        return entity.Id;
    }

    // Include UpdateAsync only if Update was requested:
    public async Task UpdateAsync(int id, CreateXxxDTO dto)
    {
        var entity = await _context.Xxxs.FindAsync(id);
        // TODO: map dto properties back to EF model fields
        await _context.SaveChangesAsync();
    }

    // Include DeleteAsync only if Delete was requested:
    public async Task<bool> DeleteAsync(int id)
    {
        var entity = await _context.Xxxs.FindAsync(id);
        if (entity == null) return false;
        _context.Xxxs.Remove(entity);
        await _context.SaveChangesAsync();
        return true;
    }
}
```

> The `_context.Xxxs` references the EF Core DbSet. The name comes from EF scaffolding and may differ from your entity name (e.g. `_context.SchoolYears`, `_context.GradeOfferings`). Always verify after generating.

---

## XxxQueries.cs

```csharp
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class XxxQueries : IXxxQueries
{
    private readonly SRJDbContext _context;

    public XxxQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<XxxDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.Xxxs.AsNoTracking(); // TODO: verify DbSet name

        if (filters != null)
        {
            // TODO: add filter conditions. Copy patterns from GradeQueries:
            // int filter:    if (filters.TryGetValue("fieldName", out var el) && el.TryGetInt32(out var val)) query = query.Where(x => x.Field == val);
            // string filter: if (filters.TryGetValue("fieldName", out var el) && el.GetString() is string val) query = query.Where(x => x.Field.ToLower().Contains(val.ToLower()));
            // id array:      if (filters.TryGetValue("id", out var idEl) && idEl.ValueKind == JsonValueKind.Array) { var ids = idEl.EnumerateArray()...; query = query.Where(x => ids.Contains(x.Id)); }
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(x => x.Id)   // TODO: choose appropriate ordering
            .Skip(skip)
            .Take(take)
            .Select(x => new XxxDTO
            {
                id = x.Id,
                // TODO: map remaining properties
            })
            .ToListAsync();
        return (items, total);
    }

    public async Task<XxxDTO?> GetByIdAsync(int id)
    {
        return await _context.Xxxs
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new XxxDTO
            {
                id = x.Id,
                // TODO: map remaining properties
            })
            .FirstOrDefaultAsync();
    }
}
```

---

## CreateXxxUseCase.cs (include only if Create was requested)

```csharp
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class CreateXxxUseCase
{
    private readonly IXxxRepository _xxxRepository;

    public CreateXxxUseCase(IXxxRepository xxxRepository)
    {
        _xxxRepository = xxxRepository;
    }

    public async Task<int> ExecuteAsync(CreateXxxDTO dto)
    {
        return await _xxxRepository.CreateAsync(dto);
    }
}
```

---

## UpdateXxxUseCase.cs (include only if Update was requested)

```csharp
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class UpdateXxxUseCase
{
    private readonly IXxxRepository _xxxRepository;

    public UpdateXxxUseCase(IXxxRepository xxxRepository)
    {
        _xxxRepository = xxxRepository;
    }

    public async Task ExecuteAsync(int id, CreateXxxDTO dto)
    {
        if (!await _xxxRepository.ExistsAsync(id))
            throw new KeyNotFoundException();

        await _xxxRepository.UpdateAsync(id, dto);
    }
}
```

---

## DeleteXxxUseCase.cs (include only if Delete was requested)

```csharp
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteXxxUseCase
{
    private readonly IXxxRepository _xxxRepository;

    public DeleteXxxUseCase(IXxxRepository xxxRepository)
    {
        _xxxRepository = xxxRepository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        return await _xxxRepository.DeleteAsync(id);
    }
}
```

---

## XxxsController.cs

Only include constructor parameters, fields, and endpoints for the operations that were actually requested.

```csharp
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/xxxs")]
public class XxxsController : ControllerBase
{
    private readonly IXxxQueries _xxxQueries;
    private readonly CreateXxxUseCase _createXxxUseCase;    // if Create
    private readonly UpdateXxxUseCase _updateXxxUseCase;    // if Update
    private readonly DeleteXxxUseCase _deleteXxxUseCase;    // if Delete

    public XxxsController(
        IXxxQueries xxxQueries,
        CreateXxxUseCase createXxxUseCase,    // if Create
        UpdateXxxUseCase updateXxxUseCase,    // if Update
        DeleteXxxUseCase deleteXxxUseCase)    // if Delete
    {
        _xxxQueries = xxxQueries;
        _createXxxUseCase = createXxxUseCase;    // if Create
        _updateXxxUseCase = updateXxxUseCase;    // if Update
        _deleteXxxUseCase = deleteXxxUseCase;    // if Delete
    }

    [HttpGet]
    [Authorize(Policy = "xxx.read")]
    public async Task<IActionResult> GetAll([FromQuery] string? range = null, [FromQuery] string? filter = null)
    {
        Dictionary<string, JsonElement>? filters = null;
        if (filter != null)
        {
            filters = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(filter);
            if (filters == null) return BadRequest("Invalid filter");
        }

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
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "xxx.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _xxxQueries.GetByIdAsync(id);
        if (item == null) return NotFound();
        return Ok(item);
    }

    // Include only if Create was requested:
    [HttpPost]
    [Authorize(Policy = "xxx.create")]
    public async Task<IActionResult> Create([FromBody] CreateXxxDTO dto)
    {
        var id = await _createXxxUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    // Include only if Update was requested:
    [HttpPut("{id:int}")]
    [Authorize(Policy = "xxx.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateXxxDTO dto)
    {
        await _updateXxxUseCase.ExecuteAsync(id, dto);
        var updated = await _xxxQueries.GetByIdAsync(id);
        return Ok(updated);
    }

    // Include only if Delete was requested:
    [HttpDelete("{id:int}")]
    [Authorize(Policy = "xxx.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteXxxUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
```

> If no filters are needed, remove the `filter` query param from `GetAll` and the `filters` deserialization block. Pass `null` as the third argument to `GetPagedAsync`.

---

## DI Registration

Add to `Infrastructure/Extensions/[Domain]ServiceExtensions.cs`:

```csharp
services.AddScoped<IXxxRepository, XxxRepository>();
services.AddScoped<IXxxQueries, XxxQueries>();
services.AddScoped<CreateXxxUseCase>();    // if Create
services.AddScoped<UpdateXxxUseCase>();    // if Update
services.AddScoped<DeleteXxxUseCase>();    // if Delete
```

---

## Auth Policies

Add to `Infrastructure/Authorization/AuthorizationPoliciesExtension.cs`:

```csharp
options.AddPolicy("xxx.read", policy =>
    policy.Requirements.Add(new PermissionRequirement("xxx.read")));
options.AddPolicy("xxx.create", policy =>           // if Create
    policy.Requirements.Add(new PermissionRequirement("xxx.create")));
options.AddPolicy("xxx.update", policy =>           // if Update
    policy.Requirements.Add(new PermissionRequirement("xxx.update")));
options.AddPolicy("xxx.delete", policy =>           // if Delete
    policy.Requirements.Add(new PermissionRequirement("xxx.delete")));
```
