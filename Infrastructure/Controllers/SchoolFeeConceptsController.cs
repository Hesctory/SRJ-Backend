using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/school-fee-concepts")]
public class SchoolFeeConceptsController : ControllerBase
{
    private readonly GetSchoolFeeConceptsUseCase _getSchoolFeeConceptsUseCase;
    private readonly GetSchoolFeeConceptByIdUseCase _getSchoolFeeConceptByIdUseCase;
    private readonly CreateSchoolFeeConceptUseCase _createSchoolFeeConceptUseCase;
    private readonly UpdateSchoolFeeConceptUseCase _updateSchoolFeeConceptUseCase;
    private readonly DeleteSchoolFeeConceptUseCase _deleteSchoolFeeConceptUseCase;

    public SchoolFeeConceptsController(
        GetSchoolFeeConceptsUseCase getSchoolFeeConceptsUseCase,
        GetSchoolFeeConceptByIdUseCase getSchoolFeeConceptByIdUseCase,
        CreateSchoolFeeConceptUseCase createSchoolFeeConceptUseCase,
        UpdateSchoolFeeConceptUseCase updateSchoolFeeConceptUseCase,
        DeleteSchoolFeeConceptUseCase deleteSchoolFeeConceptUseCase)
    {
        _getSchoolFeeConceptsUseCase = getSchoolFeeConceptsUseCase;
        _getSchoolFeeConceptByIdUseCase = getSchoolFeeConceptByIdUseCase;
        _createSchoolFeeConceptUseCase = createSchoolFeeConceptUseCase;
        _updateSchoolFeeConceptUseCase = updateSchoolFeeConceptUseCase;
        _deleteSchoolFeeConceptUseCase = deleteSchoolFeeConceptUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "school-fee-concept.read")]
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

            var (concepts, total) = await _getSchoolFeeConceptsUseCase.ExecuteAsync(start, take);
            var rangeEnd = total == 0 ? 0 : start + concepts.Count - 1;
            Response.Headers.Append("Content-Range", $"school-fee-concepts {start}-{rangeEnd}/{total}");
            return Ok(concepts);
        }
        else
        {
            var (concepts, total) = await _getSchoolFeeConceptsUseCase.ExecuteAsync(0, int.MaxValue);
            Response.Headers.Append("Content-Range", $"school-fee-concepts 0-{total - 1}/{total}");
            return Ok(concepts);
        }
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "school-fee-concept.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var concept = await _getSchoolFeeConceptByIdUseCase.ExecuteAsync(id);
        if (concept == null) return NotFound();
        return Ok(concept);
    }

    [HttpPost]
    [Authorize(Policy = "school-fee-concept.create")]
    public async Task<IActionResult> Create([FromBody] CreateSchoolFeeConceptDTO dto)
    {
        try
        {
            var id = await _createSchoolFeeConceptUseCase.ExecuteAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id }, new { id });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "school-fee-concept.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateSchoolFeeConceptDTO dto)
    {
        try
        {
            await _updateSchoolFeeConceptUseCase.ExecuteAsync(id, dto);
            var updated = await _getSchoolFeeConceptByIdUseCase.ExecuteAsync(id);
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
    [Authorize(Policy = "school-fee-concept.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteSchoolFeeConceptUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
