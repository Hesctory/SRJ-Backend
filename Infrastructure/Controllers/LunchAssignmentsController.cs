using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/lunch-assignments")]
public class LunchAssignmentsController : ControllerBase
{
    private readonly ILunchAssignmentQueries _queries;
    private readonly CreateLunchAssignmentUseCase _createUseCase;
    private readonly DeleteLunchAssignmentUseCase _deleteUseCase;

    public LunchAssignmentsController(
        ILunchAssignmentQueries queries,
        CreateLunchAssignmentUseCase createUseCase,
        DeleteLunchAssignmentUseCase deleteUseCase)
    {
        _queries = queries;
        _createUseCase = createUseCase;
        _deleteUseCase = deleteUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "lunch-assignment.read")]
    public async Task<IActionResult> GetAll([FromQuery] string? range = null, [FromQuery] string? filter = null)
    {
        var filters = ListRequest.ParseFilterDictionary(filter);
        var (skip, take) = ListRequest.ParseRange(range);
        var (items, total) = await _queries.GetPagedAsync(skip, take, filters);
        Response.SetContentRange("lunch-assignments", skip, items, total);
        return Ok(items);
    }

    [HttpGet("debt-summary")]
    [Authorize(Policy = "lunch-assignment.read")]
    public async Task<IActionResult> GetDebtSummaries([FromQuery] string? range = null, [FromQuery] string? filter = null)
    {
        var filters = ListRequest.ParseFilterDictionary(filter);
        var (skip, take) = ListRequest.ParseRange(range);
        var (items, total) = await _queries.GetDebtSummariesPagedAsync(skip, take, filters);
        Response.SetContentRange("lunch-assignments/debt-summary", skip, items, total);
        return Ok(items);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "lunch-assignment.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _queries.GetByIdAsync(id);
        return item == null ? NotFound() : Ok(item);
    }

    [HttpPost]
    [Authorize(Policy = "lunch-assignment.create")]
    public async Task<IActionResult> Create([FromBody] CreateLunchAssignmentDTO dto)
    {
        int? assignedById = int.TryParse(
            User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId) ? userId : null;

        var ids = await _createUseCase.ExecuteAsync(dto, assignedById);
        return Created(string.Empty, new { ids });
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "lunch-assignment.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
