using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/work-areas")]
public class WorkAreasController : ControllerBase
{
    private readonly IWorkAreaQueries _workAreaQueries;
    private readonly CreateWorkAreaUseCase _createWorkAreaUseCase;
    private readonly UpdateWorkAreaUseCase _updateWorkAreaUseCase;
    private readonly DeleteWorkAreaUseCase _deleteWorkAreaUseCase;

    public WorkAreasController(
        IWorkAreaQueries workAreaQueries,
        CreateWorkAreaUseCase createWorkAreaUseCase,
        UpdateWorkAreaUseCase updateWorkAreaUseCase,
        DeleteWorkAreaUseCase deleteWorkAreaUseCase)
    {
        _workAreaQueries = workAreaQueries;
        _createWorkAreaUseCase = createWorkAreaUseCase;
        _updateWorkAreaUseCase = updateWorkAreaUseCase;
        _deleteWorkAreaUseCase = deleteWorkAreaUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "work-area.read")]
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

        var (items, total) = await _workAreaQueries.GetPagedAsync(start, take, filters);
        var rangeEnd = total == 0 ? 0 : start + items.Count - 1;
        Response.Headers.Append("Content-Range", $"work-areas {start}-{rangeEnd}/{total}");
        return Ok(items);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "work-area.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _workAreaQueries.GetByIdAsync(id);
        if (item == null) return NotFound();
        return Ok(item);
    }

    [HttpPost]
    [Authorize(Policy = "work-area.create")]
    public async Task<IActionResult> Create([FromBody] CreateWorkAreaDTO dto)
    {
        var id = await _createWorkAreaUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "work-area.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateWorkAreaDTO dto)
    {
        await _updateWorkAreaUseCase.ExecuteAsync(id, dto);
        var updated = await _workAreaQueries.GetByIdAsync(id);
        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "work-area.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteWorkAreaUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
