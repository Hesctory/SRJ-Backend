using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/school-fee-concepts")]
public class SchoolFeeConceptsController : ControllerBase
{
    private readonly ISchoolFeeConceptQueries _schoolFeeConceptQueries;
    private readonly CreateSchoolFeeConceptUseCase _createSchoolFeeConceptUseCase;
    private readonly UpdateSchoolFeeConceptUseCase _updateSchoolFeeConceptUseCase;
    private readonly DeleteSchoolFeeConceptUseCase _deleteSchoolFeeConceptUseCase;

    public SchoolFeeConceptsController(
        ISchoolFeeConceptQueries schoolFeeConceptQueries,
        CreateSchoolFeeConceptUseCase createSchoolFeeConceptUseCase,
        UpdateSchoolFeeConceptUseCase updateSchoolFeeConceptUseCase,
        DeleteSchoolFeeConceptUseCase deleteSchoolFeeConceptUseCase)
    {
        _schoolFeeConceptQueries = schoolFeeConceptQueries;
        _createSchoolFeeConceptUseCase = createSchoolFeeConceptUseCase;
        _updateSchoolFeeConceptUseCase = updateSchoolFeeConceptUseCase;
        _deleteSchoolFeeConceptUseCase = deleteSchoolFeeConceptUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "school-fee-concept.read")]
    public async Task<IActionResult> GetAll([FromQuery] string? range = null)
    {
        int start = 0, take = int.MaxValue;
        if (range != null)
        {
            var bounds = JsonSerializer.Deserialize<int[]>(range)!;
            if (bounds == null || bounds.Length != 2) return BadRequest("Invalid range");
            start = bounds[0];
            take = bounds[1] - start + 1;
        }

        var (concepts, total) = await _schoolFeeConceptQueries.GetPagedAsync(start, take);
        var rangeEnd = total == 0 ? 0 : start + concepts.Count - 1;
        Response.Headers.Append("Content-Range", $"school-fee-concepts {start}-{rangeEnd}/{total}");
        return Ok(concepts);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "school-fee-concept.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var concept = await _schoolFeeConceptQueries.GetByIdAsync(id);
        if (concept == null) return NotFound();
        return Ok(concept);
    }

    [HttpPost]
    [Authorize(Policy = "school-fee-concept.create")]
    public async Task<IActionResult> Create([FromBody] CreateSchoolFeeConceptDTO dto)
    {
        var id = await _createSchoolFeeConceptUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "school-fee-concept.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateSchoolFeeConceptDTO dto)
    {
        await _updateSchoolFeeConceptUseCase.ExecuteAsync(id, dto);
        var updated = await _schoolFeeConceptQueries.GetByIdAsync(id);
        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "school-fee-concept.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteSchoolFeeConceptUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
