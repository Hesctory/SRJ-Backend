using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/students")]
public class StudentsController : ControllerBase
{
    private readonly GetStudentsUseCase _getStudentsUseCase;
    private readonly GetStudentByIdUseCase _getStudentByIdUseCase;
    private readonly CreateStudentUseCase _createStudentUseCase;
    private readonly UpdateStudentUseCase _updateStudentUseCase;
    private readonly DeleteStudentUseCase _deleteStudentUseCase;

    public StudentsController(
        GetStudentsUseCase getStudentsUseCase,
        GetStudentByIdUseCase getStudentByIdUseCase,
        CreateStudentUseCase createStudentUseCase,
        UpdateStudentUseCase updateStudentUseCase,
        DeleteStudentUseCase deleteStudentUseCase)
    {
        _getStudentsUseCase = getStudentsUseCase;
        _getStudentByIdUseCase = getStudentByIdUseCase;
        _createStudentUseCase = createStudentUseCase;
        _updateStudentUseCase = updateStudentUseCase;
        _deleteStudentUseCase = deleteStudentUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "student.read")]
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

            var (students, total) = await _getStudentsUseCase.ExecuteAsync(start, take);
            var rangeEnd = total == 0 ? 0 : start + students.Count - 1;
            Response.Headers.Append("Content-Range", $"students {start}-{rangeEnd}/{total}");
            return Ok(students);
        }
        else
        {
            var (students, total) = await _getStudentsUseCase.ExecuteAsync(0, int.MaxValue);
            Response.Headers.Append("Content-Range", $"students 0-{total - 1}/{total}");
            return Ok(students);
        }
    }

    [HttpGet("{id:int}")]
    //[Authorize(Policy = "student.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var student = await _getStudentByIdUseCase.ExecuteAsync(id);
        if (student == null) return NotFound();
        Console.WriteLine(JsonSerializer.Serialize(student, new JsonSerializerOptions { WriteIndented = true }));
        return Ok(student);
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "student.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateStudentDTO dto)
    {
        Console.WriteLine($"=== PUT /api/students/{id} ===");
        Console.WriteLine(JsonSerializer.Serialize(dto, new JsonSerializerOptions { WriteIndented = true }));
        try
        {
            await _updateStudentUseCase.ExecuteAsync(id, dto);
            var updated = await _getStudentByIdUseCase.ExecuteAsync(id);
            return Ok(updated);
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "student.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteStudentUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }

    [HttpPost]
    [Authorize(Policy = "student.create")]
    public async Task<IActionResult> Create([FromBody] CreateStudentDTO dto)
    {
        try
        {
            var id = await _createStudentUseCase.ExecuteAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id }, new { id });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }
}
