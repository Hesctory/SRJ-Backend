using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/relationship-guardians")]
public class RelationshipGuardiansController : ControllerBase
{
    private readonly GetRelationshipGuardiansUseCase _getRelationshipGuardiansUseCase;

    public RelationshipGuardiansController(GetRelationshipGuardiansUseCase getRelationshipGuardiansUseCase)
    {
        _getRelationshipGuardiansUseCase = getRelationshipGuardiansUseCase;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var relationshipGuardians = await _getRelationshipGuardiansUseCase.ExecuteAsync();
        var total = relationshipGuardians.Count;
        Response.Headers.Append("Content-Range", $"relationship-guardians 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(relationshipGuardians);
    }
}
