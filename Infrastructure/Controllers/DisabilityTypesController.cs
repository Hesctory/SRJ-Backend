using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

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
        var total = disabilityTypes.Count;
        Response.Headers.Append("Content-Range", $"disability-types 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(disabilityTypes);
    }
}
