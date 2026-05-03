using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/ruc-states")]
public class RucStatesController : ControllerBase
{
    private readonly GetRucStatesUseCase _getRucStatesUseCase;

    public RucStatesController(GetRucStatesUseCase getRucStatesUseCase)
    {
        _getRucStatesUseCase = getRucStatesUseCase;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var rucStates = await _getRucStatesUseCase.ExecuteAsync();
        var total = rucStates.Count;
        Response.Headers.Append("Content-Range", $"ruc-states 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(rucStates);
    }
}
