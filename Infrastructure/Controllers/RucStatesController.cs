using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

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
        var total = rucStates.Count;
        Response.Headers.Append("Content-Range", $"ruc-states 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(rucStates);
    }
}
