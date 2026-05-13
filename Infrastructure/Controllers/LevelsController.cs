using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/levels")]
public class LevelsController : ControllerBase
{
    private readonly ILevelQueries _levelQueries;
    private readonly CreateLevelUseCase _createLevelUseCase;
    private readonly UpdateLevelUseCase _updateLevelUseCase;
    private readonly DeleteLevelUseCase _deleteLevelUseCase;

    public LevelsController(
        ILevelQueries levelQueries,
        CreateLevelUseCase createLevelUseCase,
        UpdateLevelUseCase updateLevelUseCase,
        DeleteLevelUseCase deleteLevelUseCase)
    {
        _levelQueries = levelQueries;
        _createLevelUseCase = createLevelUseCase;
        _updateLevelUseCase = updateLevelUseCase;
        _deleteLevelUseCase = deleteLevelUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "level.read")]
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

        var (levels, total) = await _levelQueries.GetPagedAsync(start, take);
        var rangeEnd = total == 0 ? 0 : start + levels.Count - 1;
        Response.Headers.Append("Content-Range", $"levels {start}-{rangeEnd}/{total}");
        return Ok(levels);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "level.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var level = await _levelQueries.GetByIdAsync(id);
        if (level == null) return NotFound();
        return Ok(level);
    }

    [HttpPost]
    [Authorize(Policy = "level.create")]
    public async Task<IActionResult> Create([FromBody] CreateLevelDTO dto)
    {
        var id = await _createLevelUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "level.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateLevelDTO dto)
    {
        await _updateLevelUseCase.ExecuteAsync(id, dto);
        var updated = await _levelQueries.GetByIdAsync(id);
        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "level.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteLevelUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
