using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/enrollment-debts")]
public class EnrollmentDebtsController : ControllerBase
{
    private readonly IEnrollmentDebtQueries _queries;

    public EnrollmentDebtsController(IEnrollmentDebtQueries queries)
    {
        _queries = queries;
    }

    [HttpGet]
    [Authorize(Policy = "enrollment-debt.read")]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? filter = null,
        [FromQuery] string? range = null)
    {
        if (filter == null)
            return BadRequest("El parámetro 'filter' con 'enrollmentId' es requerido.");

        var f = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(filter)!;
        if (!f.TryGetValue("enrollmentId", out var enrollmentIdEl) || !enrollmentIdEl.TryGetInt32(out var enrollmentId))
            return BadRequest("El filtro 'enrollmentId' es requerido.");

        int start = 0, take = int.MaxValue;
        if (range != null)
        {
            var bounds = JsonSerializer.Deserialize<int[]>(range)!;
            if (bounds == null || bounds.Length != 2) return BadRequest("Rango inválido.");
            start = bounds[0];
            take = bounds[1] - start + 1;
        }

        var (items, total) = await _queries.GetByEnrollmentAsync(enrollmentId, start, take);
        var rangeEnd = total == 0 ? 0 : start + items.Count - 1;
        Response.Headers.Append("Content-Range", $"enrollment-debts {start}-{rangeEnd}/{total}");
        return Ok(items);
    }

    [HttpGet("{id:long}")]
    [Authorize(Policy = "enrollment-debt.read")]
    public async Task<IActionResult> GetById(long id)
    {
        var item = await _queries.GetByIdAsync(id);
        if (item == null) return NotFound();
        return Ok(item);
    }
}
