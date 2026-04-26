using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/religions")]
public class ReligionsController : ControllerBase
{
    private readonly GetReligionsUseCase _getReligionsUseCase;

    public ReligionsController(GetReligionsUseCase getReligionsUseCase)
    {
        _getReligionsUseCase = getReligionsUseCase;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var religions = await _getReligionsUseCase.ExecuteAsync();
        var total = religions.Count;
        Response.Headers.Append("Content-Range", $"religions 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(religions);
    }
}
