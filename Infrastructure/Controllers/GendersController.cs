using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/genders")]
public class GendersController : ControllerBase
{
    private readonly ILookupQueries _lookupQueries;

    public GendersController(ILookupQueries lookupQueries)
    {
        _lookupQueries = lookupQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var genders = await _lookupQueries.GetGendersAsync();
        Response.SetContentRange("genders", genders);
        return Ok(genders);
    }
}
