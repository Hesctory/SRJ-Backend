using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/school-years")]
public class SchoolYearsController : ControllerBase
{
    private readonly GetSchoolYearsUseCase _getSchoolYearsUseCase;
    private readonly GetSchoolYearByIdUseCase _getSchoolYearByIdUseCase;
    private readonly CreateSchoolYearUseCase _createSchoolYearUseCase;
    private readonly UpdateSchoolYearUseCase _updateSchoolYearUseCase;
    private readonly DeleteSchoolYearUseCase _deleteSchoolYearUseCase;

    public SchoolYearsController(
        GetSchoolYearsUseCase getSchoolYearsUseCase,
        GetSchoolYearByIdUseCase getSchoolYearByIdUseCase,
        CreateSchoolYearUseCase createSchoolYearUseCase,
        UpdateSchoolYearUseCase updateSchoolYearUseCase,
        DeleteSchoolYearUseCase deleteSchoolYearUseCase)
    {
        _getSchoolYearsUseCase = getSchoolYearsUseCase;
        _getSchoolYearByIdUseCase = getSchoolYearByIdUseCase;
        _createSchoolYearUseCase = createSchoolYearUseCase;
        _updateSchoolYearUseCase = updateSchoolYearUseCase;
        _deleteSchoolYearUseCase = deleteSchoolYearUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "school-year.read")]
    public async Task<IActionResult> GetAll([FromQuery] string? range = null, [FromQuery] string? filter = null)
    {
        Dictionary<string, JsonElement>? filters = null;
        if (filter != null)
        {
            filters = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(filter);
            if (filters == null)
                return BadRequest("Invalid filter");
        }

        int start = 0, take = int.MaxValue;
        if (range != null)
        {
            var bounds = JsonSerializer.Deserialize<int[]>(range)!;
            if (bounds == null || bounds.Length != 2)
                return BadRequest("Invalid range");
            start = bounds[0];
            take = bounds[1] - start + 1;
        }

        var (schoolYears, total) = await _getSchoolYearsUseCase.ExecuteAsync(start, take, filters);
        var rangeEnd = total == 0 ? 0 : start + schoolYears.Count - 1;
        Response.Headers.Append("Content-Range", $"school-years {start}-{rangeEnd}/{total}");
        Console.WriteLine($"=== GET /api/school-years | filter={filter ?? "none"} range={range ?? "none"} => {schoolYears.Count}/{total} ===");
        Console.WriteLine(JsonSerializer.Serialize(schoolYears, new JsonSerializerOptions { WriteIndented = true }));
        return Ok(schoolYears);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "school-year.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var schoolYear = await _getSchoolYearByIdUseCase.ExecuteAsync(id);
        if (schoolYear == null) return NotFound();
        Console.WriteLine(JsonSerializer.Serialize(schoolYear, new JsonSerializerOptions { WriteIndented = true }));
        return Ok(schoolYear);
    }

    [HttpPost]
    [Authorize(Policy = "school-year.create")]
    public async Task<IActionResult> Create([FromBody] CreateSchoolYearDTO dto)
    {
        try
        {
            var id = await _createSchoolYearUseCase.ExecuteAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id }, new { id });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "school-year.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateSchoolYearDTO dto)
    {
        try
        {
            await _updateSchoolYearUseCase.ExecuteAsync(id, dto);
            var updated = await _getSchoolYearByIdUseCase.ExecuteAsync(id);
            return Ok(updated);
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "school-year.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteSchoolYearUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
