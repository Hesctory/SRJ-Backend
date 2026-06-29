using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/school-years")]
public class SchoolYearsController : ControllerBase
{
    private readonly ISchoolYearQueries _schoolYearQueries;
    private readonly CreateSchoolYearUseCase _createSchoolYearUseCase;
    private readonly UpdateSchoolYearUseCase _updateSchoolYearUseCase;
    private readonly DeleteSchoolYearUseCase _deleteSchoolYearUseCase;

    public SchoolYearsController(
        ISchoolYearQueries schoolYearQueries,
        CreateSchoolYearUseCase createSchoolYearUseCase,
        UpdateSchoolYearUseCase updateSchoolYearUseCase,
        DeleteSchoolYearUseCase deleteSchoolYearUseCase)
    {
        _schoolYearQueries = schoolYearQueries;
        _createSchoolYearUseCase = createSchoolYearUseCase;
        _updateSchoolYearUseCase = updateSchoolYearUseCase;
        _deleteSchoolYearUseCase = deleteSchoolYearUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "school-year.read")]
    public async Task<IActionResult> GetAll([FromQuery] string? range = null, [FromQuery] string? filter = null)
    {
        var filters = ListRequest.ParseFilterDictionary(filter);
        var (skip, take) = ListRequest.ParseRange(range);
        var (schoolYears, total) = await _schoolYearQueries.GetPagedAsync(skip, take, filters);
        Response.SetContentRange("school-years", skip, schoolYears, total);
        return Ok(schoolYears);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "school-year.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var schoolYear = await _schoolYearQueries.GetByIdAsync(id);
        if (schoolYear == null) return NotFound();
        return Ok(schoolYear);
    }

    [HttpPost]
    [Authorize(Policy = "school-year.create")]
    public async Task<IActionResult> Create([FromBody] CreateSchoolYearDTO dto)
    {
        var id = await _createSchoolYearUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "school-year.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateSchoolYearDTO dto)
    {
        await _updateSchoolYearUseCase.ExecuteAsync(id, dto);
        var updated = await _schoolYearQueries.GetByIdAsync(id);
        return Ok(updated);
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
