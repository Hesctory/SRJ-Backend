using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/ethnic-self-identifications")]
public class EthnicSelfIdentificationsController : ControllerBase
{
    private readonly ILookupQueries _lookupQueries;

    public EthnicSelfIdentificationsController(ILookupQueries lookupQueries)
    {
        _lookupQueries = lookupQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var ethnicSelfIdentifications = await _lookupQueries.GetEthnicSelfIdentificationsAsync();
        var total = ethnicSelfIdentifications.Count;
        Response.Headers.Append("Content-Range", $"ethnic-self-identifications 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(ethnicSelfIdentifications);
    }
}
