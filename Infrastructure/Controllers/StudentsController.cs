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
    private readonly IStudentReportExporter _reportExporter;
    private readonly CreateStudentUseCase _createStudentUseCase;
    private readonly UpdateStudentUseCase _updateStudentUseCase;
    private readonly DeleteStudentUseCase _deleteStudentUseCase;

    public StudentsController(
        IStudentQueries studentQueries,
        IStudentReportExporter reportExporter,
        CreateStudentUseCase createStudentUseCase,
        UpdateStudentUseCase updateStudentUseCase,
        DeleteStudentUseCase deleteStudentUseCase)
    {
        _studentQueries = studentQueries;
        _reportExporter = reportExporter;
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
        var items = await _studentQueries.GetRegistrationCardAsync(
            schoolYearId, levelId, gradeId, shiftId, sectionId, ParseStudentIds(studentIds));
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

    [HttpGet("withdrawn")]
    [Authorize(Policy = "student.read")]
    public async Task<IActionResult> GetWithdrawn(
        [FromQuery] int? schoolYearId = null,
        [FromQuery] int? levelId = null,
        [FromQuery] int? gradeId = null,
        [FromQuery] int? shiftId = null,
        [FromQuery] int? sectionId = null)
    {
        var items = await _studentQueries.GetWithdrawnAsync(schoolYearId, levelId, gradeId, shiftId, sectionId);
        return Ok(items);
    }

    [HttpGet("report/export")]
    [Authorize(Policy = "student.read")]
    public async Task<IActionResult> ExportReport(
        [FromQuery] string? format = null,
        [FromQuery] int? schoolYearId = null,
        [FromQuery] int? levelId = null,
        [FromQuery] int? gradeId = null,
        [FromQuery] int? shiftId = null,
        [FromQuery] int? sectionId = null)
    {
        if (!TryParseFormat(format, out var reportFormat))
            return BadRequest("Invalid 'format'. Expected 'pdf' or 'xlsx'.");

        var file = await _reportExporter.ExportEnrolledAsync(
            schoolYearId, levelId, gradeId, shiftId, sectionId, reportFormat);
        return FileOrNoContent(file);
    }

    [HttpGet("birthdays/export")]
    [Authorize(Policy = "student.read")]
    public async Task<IActionResult> ExportBirthdays(
        [FromQuery] string? format = null,
        [FromQuery] int? schoolYearId = null,
        [FromQuery] int? levelId = null,
        [FromQuery] int? gradeId = null,
        [FromQuery] int? shiftId = null,
        [FromQuery] int? sectionId = null)
    {
        if (!TryParseFormat(format, out var reportFormat))
            return BadRequest("Invalid 'format'. Expected 'pdf' or 'xlsx'.");

        var file = await _reportExporter.ExportBirthdaysAsync(
            schoolYearId, levelId, gradeId, shiftId, sectionId, reportFormat);
        return FileOrNoContent(file);
    }

    [HttpGet("withdrawn/export")]
    [Authorize(Policy = "student.read")]
    public async Task<IActionResult> ExportWithdrawn(
        [FromQuery] string? format = null,
        [FromQuery] int? schoolYearId = null,
        [FromQuery] int? levelId = null,
        [FromQuery] int? gradeId = null,
        [FromQuery] int? shiftId = null,
        [FromQuery] int? sectionId = null)
    {
        if (!TryParseFormat(format, out var reportFormat))
            return BadRequest("Invalid 'format'. Expected 'pdf' or 'xlsx'.");

        var file = await _reportExporter.ExportWithdrawnAsync(
            schoolYearId, levelId, gradeId, shiftId, sectionId, reportFormat);
        return FileOrNoContent(file);
    }

    [HttpGet("registration-card/export")]
    [Authorize(Policy = "student.read")]
    public async Task<IActionResult> ExportRegistrationCard(
        [FromQuery] string? format = null,
        [FromQuery] int? schoolYearId = null,
        [FromQuery] int? levelId = null,
        [FromQuery] int? gradeId = null,
        [FromQuery] int? shiftId = null,
        [FromQuery] int? sectionId = null,
        [FromQuery] string? studentIds = null)
    {
        if (!TryParseFormat(format, out var reportFormat))
            return BadRequest("Invalid 'format'. Expected 'pdf' or 'xlsx'.");

        var file = await _reportExporter.ExportRegistrationCardAsync(
            schoolYearId, levelId, gradeId, shiftId, sectionId, ParseStudentIds(studentIds), reportFormat);
        return FileOrNoContent(file);
    }

    private IActionResult FileOrNoContent(ReportFile? file)
        => file is null ? NoContent() : File(file.Content, file.ContentType, file.FileName);

    private static bool TryParseFormat(string? format, out ReportFormat result)
    {
        switch (format?.Trim().ToLowerInvariant())
        {
            case "pdf": result = ReportFormat.Pdf; return true;
            case "xlsx": result = ReportFormat.Xlsx; return true;
            default: result = default; return false;
        }
    }

    private static List<int>? ParseStudentIds(string? studentIds)
    {
        if (string.IsNullOrWhiteSpace(studentIds))
            return null;

        return studentIds
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(s => int.TryParse(s, out var n) ? n : (int?)null)
            .Where(n => n.HasValue)
            .Select(n => n!.Value)
            .ToList();
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
