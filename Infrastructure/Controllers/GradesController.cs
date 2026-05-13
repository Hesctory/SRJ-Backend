using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/grades")]
public class GradesController : ControllerBase
{
    private readonly IGradeQueries _gradeQueries;
    private readonly CreateGradeUseCase _createGradeUseCase;
    private readonly UpdateGradeUseCase _updateGradeUseCase;
    private readonly DeleteGradeUseCase _deleteGradeUseCase;

    public GradesController(
        IGradeQueries gradeQueries,
        CreateGradeUseCase createGradeUseCase,
        UpdateGradeUseCase updateGradeUseCase,
        DeleteGradeUseCase deleteGradeUseCase)
    {
        _gradeQueries = gradeQueries;
        _createGradeUseCase = createGradeUseCase;
        _updateGradeUseCase = updateGradeUseCase;
        _deleteGradeUseCase = deleteGradeUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "grade.read")]
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

        var (grades, total) = await _gradeQueries.GetPagedAsync(start, take, filters);
        var rangeEnd = total == 0 ? 0 : start + grades.Count - 1;
        Response.Headers.Append("Content-Range", $"grades {start}-{rangeEnd}/{total}");
        return Ok(grades);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "grade.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var grade = await _gradeQueries.GetByIdAsync(id);
        if (grade == null) return NotFound();
        return Ok(grade);
    }

    [HttpPost]
    [Authorize(Policy = "grade.create")]
    public async Task<IActionResult> Create([FromBody] CreateGradeDTO dto)
    {
        var id = await _createGradeUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "grade.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateGradeDTO dto)
    {
        await _updateGradeUseCase.ExecuteAsync(id, dto);
        var updated = await _gradeQueries.GetByIdAsync(id);
        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "grade.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteGradeUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
