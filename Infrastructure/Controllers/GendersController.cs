using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

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
        var total = genders.Count;
        Response.Headers.Append("Content-Range", $"genders 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(genders);
    }
}
