using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

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
        var total = childbirthTypes.Count;
        Response.Headers.Append("Content-Range", $"childbirth-types 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(childbirthTypes);
    }
}
