using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/religions")]
public class ReligionsController : ControllerBase
{
    private readonly ILookupQueries _lookupQueries;

    public ReligionsController(ILookupQueries lookupQueries)
    {
        _lookupQueries = lookupQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var religions = await _lookupQueries.GetReligionsAsync();
        Response.SetContentRange("religions", religions);
        return Ok(religions);
    }
}
