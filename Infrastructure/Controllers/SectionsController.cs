using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/sections")]
public class SectionsController : ControllerBase
{
    private readonly ISectionQueries _sectionQueries;

    public SectionsController(ISectionQueries sectionQueries)
    {
        _sectionQueries = sectionQueries;
    }

    [HttpGet]
    [Authorize(Policy = "section.read")]
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

        var (sections, total) = await _sectionQueries.GetPagedAsync(start, take, filters);
        var rangeEnd = total == 0 ? 0 : start + sections.Count - 1;
        Response.Headers.Append("Content-Range", $"sections {start}-{rangeEnd}/{total}");
        return Ok(sections);
    }
}
