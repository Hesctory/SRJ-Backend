using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/enrollments")]
public class EnrollmentsController : ControllerBase
{
    private readonly IEnrollmentQueries _enrollmentQueries;
    private readonly CreateEnrollmentUseCase _createEnrollmentUseCase;

    public EnrollmentsController(
        IEnrollmentQueries enrollmentQueries,
        CreateEnrollmentUseCase createEnrollmentUseCase)
    {
        _enrollmentQueries = enrollmentQueries;
        _createEnrollmentUseCase = createEnrollmentUseCase;
    }

    [HttpGet("student/{studentId:int}")]
    [Authorize(Policy = "enrollment.read")]
    public async Task<IActionResult> GetByStudent(int studentId)
    {
        var enrollments = await _enrollmentQueries.GetByStudentAsync(studentId);
        return Ok(enrollments);
    }

    [HttpGet("student/{studentId:int}/latest")]
    [Authorize(Policy = "enrollment.read")]
    public async Task<IActionResult> GetLatestByStudent(int studentId)
    {
        var enrollment = await _enrollmentQueries.GetLatestByStudentAsync(studentId);
        if (enrollment == null) return NotFound();
        return Ok(enrollment);
    }

    [HttpPost]
    [Authorize(Policy = "enrollment.create")]
    public async Task<IActionResult> Create([FromBody] EnrollStudentDTO dto)
    {
        var enrollment = await _createEnrollmentUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetLatestByStudent), new { studentId = dto.StudentId }, enrollment);
    }
}
