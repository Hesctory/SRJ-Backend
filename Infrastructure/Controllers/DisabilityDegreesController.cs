using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/disability-degrees")]
public class DisabilityDegreesController : ControllerBase
{
    private readonly GetDisabilityDegreesUseCase _getDisabilityDegreesUseCase;

    public DisabilityDegreesController(GetDisabilityDegreesUseCase getDisabilityDegreesUseCase)
    {
        _getDisabilityDegreesUseCase = getDisabilityDegreesUseCase;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var disabilityDegrees = await _getDisabilityDegreesUseCase.ExecuteAsync();
        var total = disabilityDegrees.Count;
        Response.Headers.Append("Content-Range", $"disability-degrees 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(disabilityDegrees);
    }
}
