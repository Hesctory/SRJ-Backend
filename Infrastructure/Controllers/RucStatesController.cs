using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/ruc-states")]
public class RucStatesController : ControllerBase
{
    private readonly ILookupQueries _lookupQueries;

    public RucStatesController(ILookupQueries lookupQueries)
    {
        _lookupQueries = lookupQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var rucStates = await _lookupQueries.GetRucStatesAsync();
        Response.SetContentRange("ruc-states", rucStates);
        return Ok(rucStates);
    }
}
