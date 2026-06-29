using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/disability-types")]
public class DisabilityTypesController : ControllerBase
{
    private readonly ILookupQueries _lookupQueries;

    public DisabilityTypesController(ILookupQueries lookupQueries)
    {
        _lookupQueries = lookupQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var disabilityTypes = await _lookupQueries.GetDisabilityTypesAsync();
        Response.SetContentRange("disability-types", disabilityTypes);
        return Ok(disabilityTypes);
    }
}
