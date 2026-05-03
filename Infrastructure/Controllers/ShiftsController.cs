using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/shifts")]
public class ShiftsController : ControllerBase
{
    private readonly GetShiftsUseCase _getShiftsUseCase;
    private readonly GetShiftByIdUseCase _getShiftByIdUseCase;

    public ShiftsController(GetShiftsUseCase getShiftsUseCase, GetShiftByIdUseCase getShiftByIdUseCase)
    {
        _getShiftsUseCase = getShiftsUseCase;
        _getShiftByIdUseCase = getShiftByIdUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "shift.read")]
    public async Task<IActionResult> GetAll([FromQuery] string? range = null)
    {
        if (range != null)
        {
            var bounds = JsonSerializer.Deserialize<int[]>(range)!;
            if (bounds == null || bounds.Length != 2)
                return BadRequest("Invalid range");
            var start = bounds[0];
            var end = bounds[1];
            var take = end - start + 1;

            var (items, total) = await _getShiftsUseCase.ExecuteAsync(start, take);
            var rangeEnd = total == 0 ? 0 : start + items.Count - 1;
            Response.Headers.Append("Content-Range", $"shifts {start}-{rangeEnd}/{total}");
            return Ok(items);
        }
        else
        {
            var (items, total) = await _getShiftsUseCase.ExecuteAsync(0, int.MaxValue);
            Response.Headers.Append("Content-Range", $"shifts 0-{total - 1}/{total}");
            return Ok(items);
        }
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "shift.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _getShiftByIdUseCase.ExecuteAsync(id);
        if (item == null) return NotFound();
        return Ok(item);
    }
}
