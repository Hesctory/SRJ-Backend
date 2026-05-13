using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

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
        var total = familiarRelationshipTypes.Count;
        Response.Headers.Append("Content-Range", $"familiar-relationship-types 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(familiarRelationshipTypes);
    }
}
