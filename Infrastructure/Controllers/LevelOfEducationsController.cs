using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/level-of-educations")]
public class LevelOfEducationsController : ControllerBase
{
    private readonly ILookupQueries _lookupQueries;

    public LevelOfEducationsController(ILookupQueries lookupQueries)
    {
        _lookupQueries = lookupQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var levelOfEducations = await _lookupQueries.GetLevelOfEducationsAsync();
        var total = levelOfEducations.Count;
        Response.Headers.Append("Content-Range", $"level-of-educations 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(levelOfEducations);
    }
}
