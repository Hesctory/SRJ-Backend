using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/lunch-assignments")]
public class LunchAssignmentsController : ControllerBase
{
    private readonly ILunchAssignmentQueries _queries;
    private readonly CreateLunchAssignmentUseCase _createUseCase;
    private readonly DeleteLunchAssignmentUseCase _deleteUseCase;

    public LunchAssignmentsController(
        ILunchAssignmentQueries queries,
        CreateLunchAssignmentUseCase createUseCase,
        DeleteLunchAssignmentUseCase deleteUseCase)
    {
        _queries = queries;
        _createUseCase = createUseCase;
        _deleteUseCase = deleteUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "lunch-assignment.read")]
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

        var (items, total) = await _queries.GetPagedAsync(start, take, filters);
        var rangeEnd = total == 0 ? 0 : start + items.Count - 1;
        Response.Headers.Append("Content-Range", $"lunch-assignments {start}-{rangeEnd}/{total}");
        return Ok(items);
    }

    [HttpGet("debt-summary")]
    [Authorize(Policy = "lunch-assignment.read")]
    public async Task<IActionResult> GetDebtSummaries([FromQuery] string? range = null, [FromQuery] string? filter = null)
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

        var (items, total) = await _queries.GetDebtSummariesPagedAsync(start, take, filters);
        var rangeEnd = total == 0 ? 0 : start + items.Count - 1;
        Response.Headers.Append("Content-Range", $"lunch-assignments/debt-summary {start}-{rangeEnd}/{total}");
        return Ok(items);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "lunch-assignment.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _queries.GetByIdAsync(id);
        return item == null ? NotFound() : Ok(item);
    }

    [HttpPost]
    [Authorize(Policy = "lunch-assignment.create")]
    public async Task<IActionResult> Create([FromBody] CreateLunchAssignmentDTO dto)
    {
        int? assignedById = int.TryParse(
            User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId) ? userId : null;

        var id = await _createUseCase.ExecuteAsync(dto, assignedById);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "lunch-assignment.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
