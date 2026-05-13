using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/disability-degrees")]
public class DisabilityDegreesController : ControllerBase
{
    private readonly ILookupQueries _lookupQueries;

    public DisabilityDegreesController(ILookupQueries lookupQueries)
    {
        _lookupQueries = lookupQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var disabilityDegrees = await _lookupQueries.GetDisabilityDegreesAsync();
        var total = disabilityDegrees.Count;
        Response.Headers.Append("Content-Range", $"disability-degrees 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(disabilityDegrees);
    }
}
