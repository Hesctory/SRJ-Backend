using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/disability-types")]
public class DisabilityTypesController : ControllerBase
{
    private readonly GetDisabilityTypesUseCase _getDisabilityTypesUseCase;

    public DisabilityTypesController(GetDisabilityTypesUseCase getDisabilityTypesUseCase)
    {
        _getDisabilityTypesUseCase = getDisabilityTypesUseCase;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var disabilityTypes = await _getDisabilityTypesUseCase.ExecuteAsync();
        var total = disabilityTypes.Count;
        Response.Headers.Append("Content-Range", $"disability-types 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(disabilityTypes);
    }
}
