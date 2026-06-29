using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Http;

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
        var (skip, take) = ListRequest.ParseRange(range);
        var (institutions, total) = await _institutionQueries.GetPagedAsync(skip, take);
        Response.SetContentRange("institutions", skip, institutions, total);
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
