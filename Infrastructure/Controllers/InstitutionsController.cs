using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/institutions")]
public class InstitutionsController : ControllerBase
{
    private readonly IInstitutionQueries _institutionQueries;
    private readonly CreateInstitutionUseCase _createInstitutionUseCase;
    private readonly UpdateInstitutionUseCase _updateInstitutionUseCase;
    private readonly DeleteInstitutionUseCase _deleteInstitutionUseCase;

    public InstitutionsController(
        IInstitutionQueries institutionQueries,
        CreateInstitutionUseCase createInstitutionUseCase,
        UpdateInstitutionUseCase updateInstitutionUseCase,
        DeleteInstitutionUseCase deleteInstitutionUseCase)
    {
        _institutionQueries = institutionQueries;
        _createInstitutionUseCase = createInstitutionUseCase;
        _updateInstitutionUseCase = updateInstitutionUseCase;
        _deleteInstitutionUseCase = deleteInstitutionUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "institution.read")]
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

        var (institutions, total) = await _institutionQueries.GetPagedAsync(start, take);
        var rangeEnd = total == 0 ? 0 : start + institutions.Count - 1;
        Response.Headers.Append("Content-Range", $"institutions {start}-{rangeEnd}/{total}");
        return Ok(institutions);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "institution.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var institution = await _institutionQueries.GetByIdAsync(id);
        if (institution == null) return NotFound();
        return Ok(institution);
    }

    [HttpPost]
    [Authorize(Policy = "institution.create")]
    public async Task<IActionResult> Create([FromBody] CreateInstitutionDTO dto)
    {
        var id = await _createInstitutionUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "institution.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateInstitutionDTO dto)
    {
        await _updateInstitutionUseCase.ExecuteAsync(id, dto);
        var updated = await _institutionQueries.GetByIdAsync(id);
        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "institution.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteInstitutionUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
