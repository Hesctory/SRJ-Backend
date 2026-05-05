using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/levels")]
public class LevelsController : ControllerBase
{
    private readonly GetLevelsUseCase _getLevelsUseCase;
    private readonly GetLevelByIdUseCase _getLevelByIdUseCase;
    private readonly CreateLevelUseCase _createLevelUseCase;
    private readonly UpdateLevelUseCase _updateLevelUseCase;
    private readonly DeleteLevelUseCase _deleteLevelUseCase;

    public LevelsController(
        GetLevelsUseCase getLevelsUseCase,
        GetLevelByIdUseCase getLevelByIdUseCase,
        CreateLevelUseCase createLevelUseCase,
        UpdateLevelUseCase updateLevelUseCase,
        DeleteLevelUseCase deleteLevelUseCase)
    {
        _getLevelsUseCase = getLevelsUseCase;
        _getLevelByIdUseCase = getLevelByIdUseCase;
        _createLevelUseCase = createLevelUseCase;
        _updateLevelUseCase = updateLevelUseCase;
        _deleteLevelUseCase = deleteLevelUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "level.read")]
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

            var (levels, total) = await _getLevelsUseCase.ExecuteAsync(start, take);
            var rangeEnd = total == 0 ? 0 : start + levels.Count - 1;
            Response.Headers.Append("Content-Range", $"levels {start}-{rangeEnd}/{total}");
            return Ok(levels);
        }
        else
        {
            var (levels, total) = await _getLevelsUseCase.ExecuteAsync(0, int.MaxValue);
            Response.Headers.Append("Content-Range", $"levels 0-{total - 1}/{total}");
            return Ok(levels);
        }
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "level.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var level = await _getLevelByIdUseCase.ExecuteAsync(id);
        if (level == null) return NotFound();
        Console.WriteLine(JsonSerializer.Serialize(level, new JsonSerializerOptions { WriteIndented = true }));
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
        try
        {
            await _updateLevelUseCase.ExecuteAsync(id, dto);
            var updated = await _getLevelByIdUseCase.ExecuteAsync(id);
            return Ok(updated);
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
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
