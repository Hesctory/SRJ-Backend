using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/students")]
[Authorize]
public class StudentsController : ControllerBase
{
    private readonly GetStudentsUseCase _getStudentsUseCase;
    private readonly GetStudentByIdUseCase _getStudentByIdUseCase;

    public StudentsController(GetStudentsUseCase getStudentsUseCase, GetStudentByIdUseCase getStudentByIdUseCase)
    {
        _getStudentsUseCase = getStudentsUseCase;
        _getStudentByIdUseCase = getStudentByIdUseCase;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var students = await _getStudentsUseCase.ExecuteAsync();
        return Ok(students);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var student = await _getStudentByIdUseCase.ExecuteAsync(id);
        if (student == null) return NotFound();
        return Ok(student);
    }
}
