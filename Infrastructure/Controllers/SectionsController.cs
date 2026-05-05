using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/sections")]
public class SectionsController : ControllerBase
{
    private readonly GetSectionsUseCase _getSectionsUseCase;

    public SectionsController(GetSectionsUseCase getSectionsUseCase)
    {
        _getSectionsUseCase = getSectionsUseCase;
    }

    [HttpGet]
    [Authorize(Policy = "section.read")]
    public async Task<IActionResult> GetAll([FromQuery] int? gradeOfferingId = null)
    {
        var sections = await _getSectionsUseCase.ExecuteAsync(gradeOfferingId);
        return Ok(sections);
    }
}