using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/job-positions")]
public class JobPositionsController : ControllerBase
{
    private readonly IJobPositionQueries _jobPositionQueries;
    private readonly CreateJobPositionUseCase _createJobPositionUseCase;
    private readonly UpdateJobPositionUseCase _updateJobPositionUseCase;
    private readonly DeleteJobPositionUseCase _deleteJobPositionUseCase;

    public JobPositionsController(
        IJobPositionQueries jobPositionQueries,
        CreateJobPositionUseCase createJobPositionUseCase,
        UpdateJobPositionUseCase updateJobPositionUseCase,
        DeleteJobPositionUseCase deleteJobPositionUseCase)
    {
        _jobPositionQueries = jobPositionQueries;
        _createJobPositionUseCase = createJobPositionUseCase;
        _updateJobPositionUseCase = updateJobPositionUseCase;
        _deleteJobPositionUseCase = deleteJobPositionUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "job-position.read")]
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

        var (items, total) = await _jobPositionQueries.GetPagedAsync(start, take, filters);
        var rangeEnd = total == 0 ? 0 : start + items.Count - 1;
        Response.Headers.Append("Content-Range", $"job-positions {start}-{rangeEnd}/{total}");
        return Ok(items);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "job-position.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _jobPositionQueries.GetByIdAsync(id);
        if (item == null) return NotFound();
        return Ok(item);
    }

    [HttpPost]
    [Authorize(Policy = "job-position.create")]
    public async Task<IActionResult> Create([FromBody] CreateJobPositionDTO dto)
    {
        var id = await _createJobPositionUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "job-position.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateJobPositionDTO dto)
    {
        await _updateJobPositionUseCase.ExecuteAsync(id, dto);
        var updated = await _jobPositionQueries.GetByIdAsync(id);
        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "job-position.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteJobPositionUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
