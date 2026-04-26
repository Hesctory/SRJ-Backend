using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/familiar-relationship-types")]
public class FamiliarRelationshipTypesController : ControllerBase
{
    private readonly GetFamiliarRelationshipTypesUseCase _getFamiliarRelationshipTypesUseCase;

    public FamiliarRelationshipTypesController(GetFamiliarRelationshipTypesUseCase getFamiliarRelationshipTypesUseCase)
    {
        _getFamiliarRelationshipTypesUseCase = getFamiliarRelationshipTypesUseCase;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var familiarRelationshipTypes = await _getFamiliarRelationshipTypesUseCase.ExecuteAsync();
        var total = familiarRelationshipTypes.Count;
        Response.Headers.Append("Content-Range", $"familiar-relationship-types 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(familiarRelationshipTypes);
    }
}
