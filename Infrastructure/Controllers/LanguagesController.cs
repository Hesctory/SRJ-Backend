using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/languages")]
public class LanguagesController : ControllerBase
{
    private readonly ILookupQueries _lookupQueries;

    public LanguagesController(ILookupQueries lookupQueries)
    {
        _lookupQueries = lookupQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var languages = await _lookupQueries.GetLanguagesAsync();
        var total = languages.Count;
        Response.Headers.Append("Content-Range", $"languages 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(languages);
    }
}
