using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;

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
        EmploymentContractFilter? contractFilter = null;
        if (filter != null)
        {
            var f = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(filter)!;
            contractFilter = new EmploymentContractFilter(
                StaffMemberId: f.TryGetValue("staffMemberId", out var smEl) && smEl.TryGetInt32(out var smId) ? smId : null,
                SchoolYearId: f.TryGetValue("schoolYearId", out var syEl) && syEl.TryGetInt32(out var syId) ? syId : null,
                JobPositionId: f.TryGetValue("jobPositionId", out var jpEl) && jpEl.TryGetInt32(out var jpId) ? jpId : null,
                AreaId: f.TryGetValue("areaId", out var aEl) && aEl.TryGetInt32(out var aId) ? aId : null
            );
        }

        if (range != null)
        {
            var bounds = JsonSerializer.Deserialize<int[]>(range)!;
            if (bounds == null || bounds.Length != 2)
                return BadRequest("Invalid range");
            var start = bounds[0];
            var end = bounds[1];
            var take = end - start + 1;

            var (items, total) = await _contractQueries.GetPagedAsync(start, take, contractFilter);
            var rangeEnd = total == 0 ? 0 : start + items.Count - 1;
            Response.Headers.Append("Content-Range", $"employment-contracts {start}-{rangeEnd}/{total}");
            return Ok(items);
        }
        else
        {
            var (items, total) = await _contractQueries.GetPagedAsync(0, int.MaxValue, contractFilter);
            Response.Headers.Append("Content-Range", $"employment-contracts 0-{total - 1}/{total}");
            return Ok(items);
        }
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
