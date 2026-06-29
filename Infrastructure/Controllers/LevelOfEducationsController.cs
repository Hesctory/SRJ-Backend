using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

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
        Response.SetContentRange("level-of-educations", levelOfEducations);
        return Ok(levelOfEducations);
    }
}
