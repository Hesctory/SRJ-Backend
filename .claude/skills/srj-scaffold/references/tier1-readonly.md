# Tier 1: Read-Only Templates

These templates mirror the actual `ShiftsController` / `ShiftQueries` pattern in this codebase.
Replace every `Xxx` with the PascalCase entity name, `xxx` with lowercase, `xxxs` with lowercase plural.

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

> The `id` property is **lowercase** — this matches every existing DTO in this project (ShiftDTO, GradeDTO, etc.) and is required for frontend compatibility.

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

> If no filtering is needed, keep the `filters` parameter — it is harmless and the controller can simply not pass any filter value. Removing it is only worth doing for very simple lookups (e.g., static reference data).

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
        var query = _context.Xxxs.AsNoTracking(); // TODO: verify DbSet name matches EF scaffolded model

        if (filters != null)
        {
            // TODO: add filter conditions. Example patterns:
            // int filter:    if (filters.TryGetValue("fieldName", out var el) && el.TryGetInt32(out var val)) query = query.Where(x => x.Field == val);
            // string filter: if (filters.TryGetValue("fieldName", out var el) && el.GetString() is string val) query = query.Where(x => x.Field.ToLower().Contains(val.ToLower()));
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(x => x.Id)    // TODO: choose appropriate ordering
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

## XxxsController.cs (with filters)

Use this when the user confirmed filters are needed.

```csharp
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/xxxs")]
public class XxxsController : ControllerBase
{
    private readonly IXxxQueries _xxxQueries;

    public XxxsController(IXxxQueries xxxQueries)
    {
        _xxxQueries = xxxQueries;
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
}
```

## XxxsController.cs (no filters)

Use this when the user confirmed no filtering is needed. Drop the `filter` param entirely.

```csharp
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/xxxs")]
public class XxxsController : ControllerBase
{
    private readonly IXxxQueries _xxxQueries;

    public XxxsController(IXxxQueries xxxQueries)
    {
        _xxxQueries = xxxQueries;
    }

    [HttpGet]
    [Authorize(Policy = "xxx.read")]
    public async Task<IActionResult> GetAll([FromQuery] string? range = null)
    {
        int start = 0, take = int.MaxValue;
        if (range != null)
        {
            var bounds = JsonSerializer.Deserialize<int[]>(range)!;
            if (bounds == null || bounds.Length != 2) return BadRequest("Invalid range");
            start = bounds[0];
            take = bounds[1] - start + 1;
        }

        var (items, total) = await _xxxQueries.GetPagedAsync(start, take);
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
}
```

---

## DI Registration

Add to `Infrastructure/Extensions/[Domain]ServiceExtensions.cs`:

```csharp
services.AddScoped<IXxxQueries, XxxQueries>();
```

---

## Auth Policies

Add to `Infrastructure/Authorization/AuthorizationPoliciesExtension.cs`:

```csharp
options.AddPolicy("xxx.read", policy =>
    policy.Requirements.Add(new PermissionRequirement("xxx.read")));
```
