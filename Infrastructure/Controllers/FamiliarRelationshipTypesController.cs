using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/familiar-relationship-types")]
public class FamiliarRelationshipTypesController : ControllerBase
{
    private readonly ILookupQueries _lookupQueries;

    public FamiliarRelationshipTypesController(ILookupQueries lookupQueries)
    {
        _lookupQueries = lookupQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var familiarRelationshipTypes = await _lookupQueries.GetFamiliarRelationshipTypesAsync();
        Response.SetContentRange("familiar-relationship-types", familiarRelationshipTypes);
        return Ok(familiarRelationshipTypes);
    }
}
