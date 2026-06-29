using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Http;

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
        var staffMemberFilter = ListRequest.ParseFilter<StaffMemberFilter>(filter);
        var (skip, take) = ListRequest.ParseRange(range);
        var (items, total) = await _staffMemberQueries.GetPagedAsync(skip, take, staffMemberFilter);
        Response.SetContentRange("staff-members", skip, items, total);
        return Ok(items);
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
