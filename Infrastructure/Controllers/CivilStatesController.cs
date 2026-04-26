using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/civil-states")]
public class CivilStatesController : ControllerBase
{
    private readonly GetCivilStatesUseCase _getCivilStatesUseCase;

    public CivilStatesController(GetCivilStatesUseCase getCivilStatesUseCase)
    {
        _getCivilStatesUseCase = getCivilStatesUseCase;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var civilStates = await _getCivilStatesUseCase.ExecuteAsync();
        var total = civilStates.Count;
        Response.Headers.Append("Content-Range", $"civil-states 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(civilStates);
    }
}
