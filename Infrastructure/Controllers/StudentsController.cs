using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/students")]
public class StudentsController : ControllerBase
{
    private readonly IStudentQueries _studentQueries;
    private readonly CreateStudentUseCase _createStudentUseCase;
    private readonly UpdateStudentUseCase _updateStudentUseCase;
    private readonly DeleteStudentUseCase _deleteStudentUseCase;

    public StudentsController(
        IStudentQueries studentQueries,
        CreateStudentUseCase createStudentUseCase,
        UpdateStudentUseCase updateStudentUseCase,
        DeleteStudentUseCase deleteStudentUseCase)
    {
        _studentQueries = studentQueries;
        _createStudentUseCase = createStudentUseCase;
        _updateStudentUseCase = updateStudentUseCase;
        _deleteStudentUseCase = deleteStudentUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "student.read")]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? range = null,
        [FromQuery] string? filter = null)
    {
        StudentFilter? studentFilter = null;
        if (filter != null)
        {
            var f = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(filter)!;
            studentFilter = new StudentFilter(
                SchoolYearId: f.TryGetValue("schoolYearId", out var syEl) && syEl.TryGetInt32(out var syId) ? syId : null,
                FullName: f.TryGetValue("fullName", out var nameEl) ? nameEl.GetString() : null,
                Dni: f.TryGetValue("dni", out var dniEl) ? dniEl.GetString() : null
            );
        }

        if (range != null)
        {
            var bounds = JsonSerializer.Deserialize<int[]>(range)!;
            if (bounds == null || bounds.Length != 2)
                return BadRequest("Invalid range");
            var start = bounds[0];
            var end = bounds[1];
            var take = end - start + 1;

            var (students, total) = await _studentQueries.GetPagedAsync(start, take, studentFilter);
            var rangeEnd = total == 0 ? 0 : start + students.Count - 1;
            Response.Headers.Append("Content-Range", $"students {start}-{rangeEnd}/{total}");
            return Ok(students);
        }
        else
        {
            var (students, total) = await _studentQueries.GetPagedAsync(0, int.MaxValue, studentFilter);
            Response.Headers.Append("Content-Range", $"students 0-{total - 1}/{total}");
            return Ok(students);
        }
    }

    [HttpGet("report")]
    [Authorize(Policy = "student.read")]
    public async Task<IActionResult> GetReport(
        [FromQuery] int? schoolYearId = null,
        [FromQuery] int? levelId = null,
        [FromQuery] int? gradeId = null,
        [FromQuery] int? shiftId = null,
        [FromQuery] int? sectionId = null)
    {
        var items = await _studentQueries.GetReportAsync(schoolYearId, levelId, gradeId, shiftId, sectionId);
        return Ok(items);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "student.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var student = await _studentQueries.GetByIdAsync(id);
        if (student == null) return NotFound();
        return Ok(student);
    }

    [HttpPost]
    [Authorize(Policy = "student.create")]
    public async Task<IActionResult> Create([FromBody] CreateStudentDTO dto)
    {
        var id = await _createStudentUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "student.update")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateStudentDTO dto)
    {
        await _updateStudentUseCase.ExecuteAsync(id, dto);
        var updated = await _studentQueries.GetByIdAsync(id);
        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "student.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteStudentUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
