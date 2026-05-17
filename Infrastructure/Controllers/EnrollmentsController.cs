using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.Mappers;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/enrollments")]
public class EnrollmentsController : ControllerBase
{
    private readonly IEnrollmentQueries _enrollmentQueries;
    private readonly CreateEnrollmentUseCase _createEnrollmentUseCase;
    private readonly UpdateEnrollmentUseCase _updateEnrollmentUseCase;
    private readonly DeleteEnrollmentUseCase _deleteEnrollmentUseCase;

    public EnrollmentsController(
        IEnrollmentQueries enrollmentQueries,
        CreateEnrollmentUseCase createEnrollmentUseCase,
        UpdateEnrollmentUseCase updateEnrollmentUseCase,
        DeleteEnrollmentUseCase deleteEnrollmentUseCase)
    {
        _enrollmentQueries = enrollmentQueries;
        _createEnrollmentUseCase = createEnrollmentUseCase;
        _updateEnrollmentUseCase = updateEnrollmentUseCase;
        _deleteEnrollmentUseCase = deleteEnrollmentUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "enrollment.read")]
    public async Task<IActionResult> GetByStudent(
        [FromQuery] string? filter = null,
        [FromQuery] string? range = null,
        [FromQuery] string? sort = null)
    {
        int? studentId = null;
        if (filter != null)
        {
            var f = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(filter)!;
            if (f.TryGetValue("studentId", out var sidEl) && sidEl.TryGetInt32(out var sid))
                studentId = sid;
        }

        if (studentId == null)
            return BadRequest("studentId filter is required");

        var enrollments = await _enrollmentQueries.GetByStudentAsync(studentId.Value);

        if (sort != null)
        {
            var sortParts = JsonSerializer.Deserialize<string[]>(sort)!;
            var field = sortParts[0].ToLowerInvariant();
            var desc = sortParts.Length > 1 && sortParts[1].ToUpperInvariant() == "DESC";

            enrollments = field switch
            {
                "year"    => desc ? enrollments.OrderByDescending(e => e.Year).ToList()    : enrollments.OrderBy(e => e.Year).ToList(),
                "level"   => desc ? enrollments.OrderByDescending(e => e.Level).ToList()   : enrollments.OrderBy(e => e.Level).ToList(),
                "grade"   => desc ? enrollments.OrderByDescending(e => e.Grade).ToList()   : enrollments.OrderBy(e => e.Grade).ToList(),
                "shift"   => desc ? enrollments.OrderByDescending(e => e.Shift).ToList()   : enrollments.OrderBy(e => e.Shift).ToList(),
                "section" => desc ? enrollments.OrderByDescending(e => e.Section).ToList() : enrollments.OrderBy(e => e.Section).ToList(),
                _         => desc ? enrollments.OrderByDescending(e => e.Id).ToList()      : enrollments.OrderBy(e => e.Id).ToList(),
            };
        }

        var total = enrollments.Count;

        if (range != null)
        {
            var bounds = JsonSerializer.Deserialize<int[]>(range)!;
            var start = bounds[0];
            var end = bounds[1];
            var paged = enrollments.Skip(start).Take(end - start + 1).ToList();
            var rangeEnd = total == 0 ? 0 : start + paged.Count - 1;
            Response.Headers.Append("Content-Range", $"enrollments {start}-{rangeEnd}/{total}");
            return Ok(paged);
        }

        var lastIndex = total == 0 ? 0 : total - 1;
        Response.Headers.Append("Content-Range", $"enrollments 0-{lastIndex}/{total}");
        return Ok(enrollments);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "enrollment.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var enrollment = await _enrollmentQueries.GetByIdAsync(id);
        if (enrollment == null) return NotFound();
        return Ok(enrollment);
    }

    [HttpGet("student/{studentId:int}/latest")]
    [Authorize(Policy = "enrollment.read")]
    public async Task<IActionResult> GetLatestByStudent(int studentId)
    {
        var enrollment = await _enrollmentQueries.GetLatestByStudentAsync(studentId);
        if (enrollment == null) return NotFound();
        return Ok(enrollment);
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "enrollment.update")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateEnrollmentDTO dto)
    {
        var enrollment = await _updateEnrollmentUseCase.ExecuteAsync(id, dto);
        return Ok(enrollment);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "enrollment.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteEnrollmentUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }

    [HttpPost]
    [Authorize(Policy = "enrollment.create")]
    public async Task<IActionResult> Create([FromBody] EnrollStudentDTO dto)
    {
        var enrollment = await _createEnrollmentUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetLatestByStudent), new { studentId = dto.StudentId }, EnrollmentMapper.ToDTO(enrollment));
    }
}
