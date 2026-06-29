using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Http;

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
        var studentFilter = ListRequest.ParseFilter<StudentFilter>(filter);
        var (skip, take) = ListRequest.ParseRange(range);
        var (students, total) = await _studentQueries.GetPagedAsync(skip, take, studentFilter);
        Response.SetContentRange("students", skip, students, total);
        return Ok(students);
    }

    [HttpGet("registration-card")]
    [Authorize(Policy = "student.read")]
    public async Task<IActionResult> GetRegistrationCard(
        [FromQuery] int? schoolYearId = null,
        [FromQuery] int? levelId = null,
        [FromQuery] int? gradeId = null,
        [FromQuery] int? shiftId = null,
        [FromQuery] int? sectionId = null,
        [FromQuery] string? studentIds = null)
    {
        List<int>? parsedStudentIds = null;
        if (!string.IsNullOrWhiteSpace(studentIds))
        {
            parsedStudentIds = studentIds
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(s => int.TryParse(s, out var n) ? n : (int?)null)
                .Where(n => n.HasValue)
                .Select(n => n!.Value)
                .ToList();
        }

        var items = await _studentQueries.GetRegistrationCardAsync(
            schoolYearId, levelId, gradeId, shiftId, sectionId, parsedStudentIds);
        return Ok(items);
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

    [HttpGet("birthdays")]
    [Authorize(Policy = "student.read")]
    public async Task<IActionResult> GetBirthdays(
        [FromQuery] int? schoolYearId = null,
        [FromQuery] int? levelId = null,
        [FromQuery] int? gradeId = null,
        [FromQuery] int? shiftId = null,
        [FromQuery] int? sectionId = null)
    {
        var items = await _studentQueries.GetBirthdaysAsync(schoolYearId, levelId, gradeId, shiftId, sectionId);
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
