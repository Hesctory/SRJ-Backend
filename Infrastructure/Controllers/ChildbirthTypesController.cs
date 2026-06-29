using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/childbirth-types")]
public class ChildbirthTypesController : ControllerBase
{
    private readonly ILookupQueries _lookupQueries;

    public ChildbirthTypesController(ILookupQueries lookupQueries)
    {
        _lookupQueries = lookupQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var childbirthTypes = await _lookupQueries.GetChildbirthTypesAsync();
        Response.SetContentRange("childbirth-types", childbirthTypes);
        return Ok(childbirthTypes);
    }
}
