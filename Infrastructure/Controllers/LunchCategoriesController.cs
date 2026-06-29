using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/lunch-categories")]
public class LunchCategoriesController : ControllerBase
{
    private readonly ILunchCategoryQueries _lunchCategoryQueries;
    private readonly CreateLunchCategoryUseCase _createLunchCategoryUseCase;
    private readonly UpdateLunchCategoryUseCase _updateLunchCategoryUseCase;
    private readonly DeleteLunchCategoryUseCase _deleteLunchCategoryUseCase;

    public LunchCategoriesController(
        ILunchCategoryQueries lunchCategoryQueries,
        CreateLunchCategoryUseCase createLunchCategoryUseCase,
        UpdateLunchCategoryUseCase updateLunchCategoryUseCase,
        DeleteLunchCategoryUseCase deleteLunchCategoryUseCase)
    {
        _lunchCategoryQueries = lunchCategoryQueries;
        _createLunchCategoryUseCase = createLunchCategoryUseCase;
        _updateLunchCategoryUseCase = updateLunchCategoryUseCase;
        _deleteLunchCategoryUseCase = deleteLunchCategoryUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "lunch-category.read")]
    public async Task<IActionResult> GetAll([FromQuery] string? range = null)
    {
        var (skip, take) = ListRequest.ParseRange(range);
        var (items, total) = await _lunchCategoryQueries.GetPagedAsync(skip, take);
        Response.SetContentRange("lunch-categories", skip, items, total);
        return Ok(items);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "lunch-category.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _lunchCategoryQueries.GetByIdAsync(id);
        return item == null ? NotFound() : Ok(item);
    }

    [HttpPost]
    [Authorize(Policy = "lunch-category.create")]
    public async Task<IActionResult> Create([FromBody] CreateLunchCategoryDTO dto)
    {
        var id = await _createLunchCategoryUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "lunch-category.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateLunchCategoryDTO dto)
    {
        await _updateLunchCategoryUseCase.ExecuteAsync(id, dto);
        var updated = await _lunchCategoryQueries.GetByIdAsync(id);
        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "lunch-category.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteLunchCategoryUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
