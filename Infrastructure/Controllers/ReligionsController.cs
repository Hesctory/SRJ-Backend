using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

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
        var total = religions.Count;
        Response.Headers.Append("Content-Range", $"religions 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(religions);
    }
}
