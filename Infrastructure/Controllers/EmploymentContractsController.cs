using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/employment-contracts")]
public class EmploymentContractsController : ControllerBase
{
    private readonly IEmploymentContractQueries _contractQueries;
    private readonly CreateEmploymentContractUseCase _createContractUseCase;
    private readonly UpdateEmploymentContractUseCase _updateContractUseCase;
    private readonly DeleteEmploymentContractUseCase _deleteContractUseCase;

    public EmploymentContractsController(
        IEmploymentContractQueries contractQueries,
        CreateEmploymentContractUseCase createContractUseCase,
        UpdateEmploymentContractUseCase updateContractUseCase,
        DeleteEmploymentContractUseCase deleteContractUseCase)
    {
        _contractQueries = contractQueries;
        _createContractUseCase = createContractUseCase;
        _updateContractUseCase = updateContractUseCase;
        _deleteContractUseCase = deleteContractUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "employment-contract.read")]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? range = null,
        [FromQuery] string? filter = null)
    {
        var contractFilter = ListRequest.ParseFilter<EmploymentContractFilter>(filter);
        var (skip, take) = ListRequest.ParseRange(range);
        var (items, total) = await _contractQueries.GetPagedAsync(skip, take, contractFilter);
        Response.SetContentRange("employment-contracts", skip, items, total);
        return Ok(items);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "employment-contract.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var contract = await _contractQueries.GetByIdAsync(id);
        if (contract == null) return NotFound();
        return Ok(contract);
    }

    [HttpPost]
    [Authorize(Policy = "employment-contract.create")]
    public async Task<IActionResult> Create([FromBody] CreateEmploymentContractDTO dto)
    {
        var id = await _createContractUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "employment-contract.update")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateEmploymentContractDTO dto)
    {
        await _updateContractUseCase.ExecuteAsync(id, dto);
        var updated = await _contractQueries.GetByIdAsync(id);
        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "employment-contract.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteContractUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
