using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Http;

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
        var filters = ListRequest.ParseFilterDictionary(filter);
        var (skip, take) = ListRequest.ParseRange(range);
        var (grades, total) = await _gradeQueries.GetPagedAsync(skip, take, filters);
        Response.SetContentRange("grades", skip, grades, total);
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
