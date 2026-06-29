using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

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
        Response.SetContentRange("ethnic-self-identifications", ethnicSelfIdentifications);
        return Ok(ethnicSelfIdentifications);
    }
}
