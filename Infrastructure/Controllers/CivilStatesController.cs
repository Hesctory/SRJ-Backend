using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

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
        Response.SetContentRange("civil-states", civilStates);
        return Ok(civilStates);
    }
}
