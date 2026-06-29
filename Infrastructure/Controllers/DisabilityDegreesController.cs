using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

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
        Response.SetContentRange("disability-degrees", disabilityDegrees);
        return Ok(disabilityDegrees);
    }
}
