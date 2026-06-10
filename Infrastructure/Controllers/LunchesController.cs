using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/lunches")]
public class LunchesController : ControllerBase
{
    private readonly ILunchQueries _lunchQueries;
    private readonly CreateLunchUseCase _createLunchUseCase;
    private readonly UpdateLunchUseCase _updateLunchUseCase;
    private readonly DeleteLunchUseCase _deleteLunchUseCase;

    public LunchesController(
        ILunchQueries lunchQueries,
        CreateLunchUseCase createLunchUseCase,
        UpdateLunchUseCase updateLunchUseCase,
        DeleteLunchUseCase deleteLunchUseCase)
    {
        _lunchQueries = lunchQueries;
        _createLunchUseCase = createLunchUseCase;
        _updateLunchUseCase = updateLunchUseCase;
        _deleteLunchUseCase = deleteLunchUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "lunch.read")]
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

        var (items, total) = await _lunchQueries.GetPagedAsync(start, take);
        var rangeEnd = total == 0 ? 0 : start + items.Count - 1;
        Response.Headers.Append("Content-Range", $"lunches {start}-{rangeEnd}/{total}");
        return Ok(items);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "lunch.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _lunchQueries.GetByIdAsync(id);
        return item == null ? NotFound() : Ok(item);
    }

    [HttpPost]
    [Authorize(Policy = "lunch.create")]
    public async Task<IActionResult> Create([FromBody] CreateLunchDTO dto)
    {
        var id = await _createLunchUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "lunch.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateLunchDTO dto)
    {
        await _updateLunchUseCase.ExecuteAsync(id, dto);
        var updated = await _lunchQueries.GetByIdAsync(id);
        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "lunch.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteLunchUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
