using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/grade-offerings")]
public class GradeOfferingsController : ControllerBase
{
    private readonly IGradeOfferingQueries _gradeOfferingQueries;
    private readonly CreateGradeOfferingUseCase _createGradeOfferingUseCase;
    private readonly UpdateGradeOfferingUseCase _updateGradeOfferingUseCase;
    private readonly DeleteGradeOfferingUseCase _deleteGradeOfferingUseCase;

    public GradeOfferingsController(
        IGradeOfferingQueries gradeOfferingQueries,
        CreateGradeOfferingUseCase createGradeOfferingUseCase,
        UpdateGradeOfferingUseCase updateGradeOfferingUseCase,
        DeleteGradeOfferingUseCase deleteGradeOfferingUseCase)
    {
        _gradeOfferingQueries = gradeOfferingQueries;
        _createGradeOfferingUseCase = createGradeOfferingUseCase;
        _updateGradeOfferingUseCase = updateGradeOfferingUseCase;
        _deleteGradeOfferingUseCase = deleteGradeOfferingUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "grade-offering.read")]
    public async Task<IActionResult> GetAll([FromQuery] string? range = null, [FromQuery] string? filter = null)
    {
        var filters = ListRequest.ParseFilterDictionary(filter);
        var (skip, take) = ListRequest.ParseRange(range);
        var (items, total) = await _gradeOfferingQueries.GetPagedAsync(skip, take, filters);
        Response.SetContentRange("grade-offerings", skip, items, total);
        return Ok(items);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "grade-offering.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _gradeOfferingQueries.GetByIdAsync(id);
        if (item == null) return NotFound();
        return Ok(item);
    }

    [HttpPost]
    [Authorize(Policy = "grade-offering.create")]
    public async Task<IActionResult> Create([FromBody] CreateGradeOfferingDTO dto)
    {
        var id = await _createGradeOfferingUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "grade-offering.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateGradeOfferingDTO dto)
    {
        await _updateGradeOfferingUseCase.ExecuteAsync(id, dto);
        var updated = await _gradeOfferingQueries.GetByIdAsync(id);
        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "grade-offering.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteGradeOfferingUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
