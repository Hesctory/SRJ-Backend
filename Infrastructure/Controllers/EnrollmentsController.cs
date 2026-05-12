using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/enrollments")]
public class EnrollmentsController : ControllerBase
{
    private readonly GetEnrollmentsByStudentUseCase _getEnrollmentsByStudentUseCase;
    private readonly GetLatestEnrollmentByStudentUseCase _getLatestEnrollmentByStudentUseCase;
    private readonly CreateEnrollmentUseCase _createEnrollmentUseCase;

    public EnrollmentsController(
        GetEnrollmentsByStudentUseCase getEnrollmentsByStudentUseCase,
        GetLatestEnrollmentByStudentUseCase getLatestEnrollmentByStudentUseCase,
        CreateEnrollmentUseCase createEnrollmentUseCase)
    {
        _getEnrollmentsByStudentUseCase = getEnrollmentsByStudentUseCase;
        _getLatestEnrollmentByStudentUseCase = getLatestEnrollmentByStudentUseCase;
        _createEnrollmentUseCase = createEnrollmentUseCase;
    }

    [HttpGet("student/{studentId:int}")]
    [Authorize(Policy = "enrollment.read")]
    public async Task<IActionResult> GetByStudent(int studentId)
    {
        var enrollments = await _getEnrollmentsByStudentUseCase.ExecuteAsync(studentId);
        return Ok(enrollments);
    }

    [HttpGet("student/{studentId:int}/latest")]
    [Authorize(Policy = "enrollment.read")]
    public async Task<IActionResult> GetLatestByStudent(int studentId)
    {
        var enrollment = await _getLatestEnrollmentByStudentUseCase.ExecuteAsync(studentId);
        if (enrollment == null) return NotFound();
        return Ok(enrollment);
    }

    [HttpPost]
    [Authorize(Policy = "enrollment.create")]
    public async Task<IActionResult> Create([FromBody] EnrollStudentDTO dto)
    {
        try
        {
            var enrollment = await _createEnrollmentUseCase.ExecuteAsync(dto);
            return CreatedAtAction(nameof(GetLatestByStudent), new { studentId = dto.StudentId }, enrollment);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }
}
