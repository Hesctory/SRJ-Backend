using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/civil-states")]
public class CivilStatesController : ControllerBase
{
    private readonly ILookupQueries _lookupQueries;

    public CivilStatesController(ILookupQueries lookupQueries)
    {
        _lookupQueries = lookupQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var civilStates = await _lookupQueries.GetCivilStatesAsync();
        var total = civilStates.Count;
        Response.Headers.Append("Content-Range", $"civil-states 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(civilStates);
    }
}
