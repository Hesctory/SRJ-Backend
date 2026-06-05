using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/staff-members")]
public class StaffMembersController : ControllerBase
{
    private readonly IStaffMemberQueries _staffMemberQueries;
    private readonly CreateStaffMemberUseCase _createStaffMemberUseCase;
    private readonly UpdateStaffMemberUseCase _updateStaffMemberUseCase;
    private readonly DeleteStaffMemberUseCase _deleteStaffMemberUseCase;

    public StaffMembersController(
        IStaffMemberQueries staffMemberQueries,
        CreateStaffMemberUseCase createStaffMemberUseCase,
        UpdateStaffMemberUseCase updateStaffMemberUseCase,
        DeleteStaffMemberUseCase deleteStaffMemberUseCase)
    {
        _staffMemberQueries = staffMemberQueries;
        _createStaffMemberUseCase = createStaffMemberUseCase;
        _updateStaffMemberUseCase = updateStaffMemberUseCase;
        _deleteStaffMemberUseCase = deleteStaffMemberUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "staff-member.read")]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? range = null,
        [FromQuery] string? filter = null)
    {
        StaffMemberFilter? staffMemberFilter = null;
        if (filter != null)
        {
            var f = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(filter)!;
            staffMemberFilter = new StaffMemberFilter(
                FullName: f.TryGetValue("fullName", out var nameEl) ? nameEl.GetString() : null,
                DocumentNumber: f.TryGetValue("documentNumber", out var docEl) ? docEl.GetString() : null,
                EmployeeCode: f.TryGetValue("employeeCode", out var codeEl) ? codeEl.GetString() : null,
                IsActive: f.TryGetValue("isActive", out var activeEl) && (activeEl.ValueKind == JsonValueKind.True || activeEl.ValueKind == JsonValueKind.False) ? activeEl.GetBoolean() : null,
                IsArchived: f.TryGetValue("isArchived", out var archivedEl) && (archivedEl.ValueKind == JsonValueKind.True || archivedEl.ValueKind == JsonValueKind.False) ? archivedEl.GetBoolean() : null
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

            var (items, total) = await _staffMemberQueries.GetPagedAsync(start, take, staffMemberFilter);
            var rangeEnd = total == 0 ? 0 : start + items.Count - 1;
            Response.Headers.Append("Content-Range", $"staff-members {start}-{rangeEnd}/{total}");
            return Ok(items);
        }
        else
        {
            var (items, total) = await _staffMemberQueries.GetPagedAsync(0, int.MaxValue, staffMemberFilter);
            Response.Headers.Append("Content-Range", $"staff-members 0-{total - 1}/{total}");
            return Ok(items);
        }
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "staff-member.read")]
    public async Task<IActionResult> GetById(int id)
    {
        var staffMember = await _staffMemberQueries.GetByIdAsync(id);
        if (staffMember == null) return NotFound();
        return Ok(staffMember);
    }

    [HttpPost]
    [Authorize(Policy = "staff-member.create")]
    public async Task<IActionResult> Create([FromBody] CreateStaffMemberDTO dto)
    {
        var id = await _createStaffMemberUseCase.ExecuteAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id }, new { id });
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "staff-member.update")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateStaffMemberDTO dto)
    {
        await _updateStaffMemberUseCase.ExecuteAsync(id, dto);
        var updated = await _staffMemberQueries.GetByIdAsync(id);
        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "staff-member.delete")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _deleteStaffMemberUseCase.ExecuteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
