using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/grade-offerings")]
public class GradeOfferingsController : ControllerBase
{
    private readonly GetGradeOfferingsUseCase _getGradeOfferingsUseCase;
    private readonly GetGradeOfferingByIdUseCase _getGradeOfferingByIdUseCase;
    private readonly CreateGradeOfferingUseCase _createGradeOfferingUseCase;
    private readonly UpdateGradeOfferingUseCase _updateGradeOfferingUseCase;
    private readonly DeleteGradeOfferingUseCase _deleteGradeOfferingUseCase;

    public GradeOfferingsController(
        GetGradeOfferingsUseCase getGradeOfferingsUseCase,
        GetGradeOfferingByIdUseCase getGradeOfferingByIdUseCase,
        CreateGradeOfferingUseCase createGradeOfferingUseCase,
        UpdateGradeOfferingUseCase updateGradeOfferingUseCase,
        DeleteGradeOfferingUseCase deleteGradeOfferingUseCase)
    {
        _getGradeOfferingsUseCase = getGradeOfferingsUseCase;
        _getGradeOfferingByIdUseCase = getGradeOfferingByIdUseCase;
        _createGradeOfferingUseCase = createGradeOfferingUseCase;
        _updateGradeOfferingUseCase = updateGradeOfferingUseCase;
        _deleteGradeOfferingUseCase = deleteGradeOfferingUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "grade-offering.read")]
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

        var (items, total) = await _getGradeOfferingsUseCase.ExecuteAsync(start, take, filters);
        var rangeEnd = total == 0 ? 0 : start + items.Count - 1;
        Response.Headers.Append("Content-Range", $"grade-offerings {start}-{rangeEnd}/{total}");
        Console.WriteLine($"=== GET /api/grade-offerings | filter={filter ?? "none"} range={range ?? "none"} => {items.Count}/{total} ===");
        Console.WriteLine(JsonSerializer.Serialize(items, new JsonSerializerOptions { WriteIndented = true }));
        return Ok(items);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "grade-offering.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _getGradeOfferingByIdUseCase.ExecuteAsync(id);
        if (item == null) return NotFound();
        Console.WriteLine(JsonSerializer.Serialize(item, new JsonSerializerOptions { WriteIndented = true }));
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
        try
        {
            await _updateGradeOfferingUseCase.ExecuteAsync(id, dto);
            return NoContent();
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
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
