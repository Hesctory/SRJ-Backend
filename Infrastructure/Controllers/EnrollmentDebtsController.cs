using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

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

        var f = ListRequest.ParseFilterDictionary(filter)!;
        if (!f.TryGetValue("enrollmentId", out var enrollmentIdEl) || !enrollmentIdEl.TryGetInt32(out var enrollmentId))
            return BadRequest("El filtro 'enrollmentId' es requerido.");

        var (skip, take) = ListRequest.ParseRange(range);
        var (items, total) = await _queries.GetByEnrollmentAsync(enrollmentId, skip, take);
        Response.SetContentRange("enrollment-debts", skip, items, total);
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
