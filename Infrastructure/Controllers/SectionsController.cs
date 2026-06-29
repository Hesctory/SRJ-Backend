using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/sections")]
public class SectionsController : ControllerBase
{
    private readonly ISectionQueries _sectionQueries;

    public SectionsController(ISectionQueries sectionQueries)
    {
        _sectionQueries = sectionQueries;
    }

    [HttpGet]
    [Authorize(Policy = "section.read")]
    public async Task<IActionResult> GetAll([FromQuery] string? range = null, [FromQuery] string? filter = null)
    {
        var filters = ListRequest.ParseFilterDictionary(filter);
        var (skip, take) = ListRequest.ParseRange(range);
        var (sections, total) = await _sectionQueries.GetPagedAsync(skip, take, filters);
        Response.SetContentRange("sections", skip, sections, total);
        return Ok(sections);
    }
}
