using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/shifts")]
public class ShiftsController : ControllerBase
{
    private readonly IShiftQueries _shiftQueries;

    public ShiftsController(IShiftQueries shiftQueries)
    {
        _shiftQueries = shiftQueries;
    }

    [HttpGet]
    [Authorize(Policy = "shift.read")]
    public async Task<IActionResult> GetAll([FromQuery] string? range = null, [FromQuery] string? filter = null)
    {
        var filters = ListRequest.ParseFilterDictionary(filter);
        var (skip, take) = ListRequest.ParseRange(range);
        var (items, total) = await _shiftQueries.GetPagedAsync(skip, take, filters);
        Response.SetContentRange("shifts", skip, items, total);
        return Ok(items);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "shift.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _shiftQueries.GetByIdAsync(id);
        if (item == null) return NotFound();
        return Ok(item);
    }
}
