using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/institutions")]
public class InstitutionsController : ControllerBase
{
    private readonly GetInstitutionsUseCase _getInstitutionsUseCase;
    private readonly GetInstitutionByIdUseCase _getInstitutionByIdUseCase;
    private readonly CreateInstitutionUseCase _createInstitutionUseCase;
    private readonly UpdateInstitutionUseCase _updateInstitutionUseCase;
    private readonly DeleteInstitutionUseCase _deleteInstitutionUseCase;

    public InstitutionsController(
        GetInstitutionsUseCase getInstitutionsUseCase,
        GetInstitutionByIdUseCase getInstitutionByIdUseCase,
        CreateInstitutionUseCase createInstitutionUseCase,
        UpdateInstitutionUseCase updateInstitutionUseCase,
        DeleteInstitutionUseCase deleteInstitutionUseCase)
    {
        _getInstitutionsUseCase = getInstitutionsUseCase;
        _getInstitutionByIdUseCase = getInstitutionByIdUseCase;
        _createInstitutionUseCase = createInstitutionUseCase;
        _updateInstitutionUseCase = updateInstitutionUseCase;
        _deleteInstitutionUseCase = deleteInstitutionUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "institution.read")]
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

            var (institutions, total) = await _getInstitutionsUseCase.ExecuteAsync(start, take);
            var rangeEnd = total == 0 ? 0 : start + institutions.Count - 1;
            Response.Headers.Append("Content-Range", $"institutions {start}-{rangeEnd}/{total}");
            return Ok(institutions);
        }
        else
        {
            var (institutions, total) = await _getInstitutionsUseCase.ExecuteAsync(0, int.MaxValue);
            Response.Headers.Append("Content-Range", $"institutions 0-{total - 1}/{total}");
            return Ok(institutions);
        }
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "institution.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var institution = await _getInstitutionByIdUseCase.ExecuteAsync(id);
        if (institution == null) return NotFound();
        Console.WriteLine(JsonSerializer.Serialize(institution, new JsonSerializerOptions { WriteIndented = true }));
        return Ok(institution);
    }

    [HttpPost]
    [Authorize(Policy = "institution.create")]
    public async Task<IActionResult> Create([FromBody] CreateInstitutionDTO dto)
    {
        try
        {
            var id = await _createInstitutionUseCase.ExecuteAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id }, new { id });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "institution.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateInstitutionDTO dto)
    {
        try
        {
            await _updateInstitutionUseCase.ExecuteAsync(id, dto);
            var updated = await _getInstitutionByIdUseCase.ExecuteAsync(id);
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
    [Authorize(Policy = "institution.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteInstitutionUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
