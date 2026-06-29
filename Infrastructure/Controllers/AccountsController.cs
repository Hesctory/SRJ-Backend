using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/accounting-plan")]
public class AccountsController : ControllerBase
{
    private readonly IAccountQueries _queries;
    private readonly CreateAccountUseCase _createUseCase;
    private readonly UpdateAccountUseCase _updateUseCase;
    private readonly DeleteAccountUseCase _deleteUseCase;

    public AccountsController(
        IAccountQueries queries,
        CreateAccountUseCase createUseCase,
        UpdateAccountUseCase updateUseCase,
        DeleteAccountUseCase deleteUseCase)
    {
        _queries = queries;
        _createUseCase = createUseCase;
        _updateUseCase = updateUseCase;
        _deleteUseCase = deleteUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "accounting-plan.read")]
    public async Task<IActionResult> GetAll([FromQuery] string? range = null, [FromQuery] string? filter = null)
    {
        var filters = ListRequest.ParseFilterDictionary(filter);
        var (skip, take) = ListRequest.ParseRange(range);
        var (items, total) = await _queries.GetPagedAsync(skip, take, filters);
        Response.SetContentRange("accounting-plan", skip, items, total);
        return Ok(items);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "accounting-plan.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _queries.GetByIdAsync(id);
        if (item == null) return NotFound();
        return Ok(item);
    }

    [HttpPost]
    [Authorize(Policy = "accounting-plan.create")]
    public async Task<IActionResult> Create([FromBody] CreateAccountDTO dto)
    {
        var id = await _createUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "accounting-plan.update")]
    public async Task<IActionResult> Update(int id, [FromBody] CreateAccountDTO dto)
    {
        await _updateUseCase.ExecuteAsync(id, dto);
        var updated = await _queries.GetByIdAsync(id);
        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "accounting-plan.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
