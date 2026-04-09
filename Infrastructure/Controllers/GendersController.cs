using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/genders")]
public class GendersController : ControllerBase
{
    private readonly GetGendersUseCase _getGendersUseCase;

    public GendersController(GetGendersUseCase getGendersUseCase)
    {
        _getGendersUseCase = getGendersUseCase;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var genders = await _getGendersUseCase.ExecuteAsync();
        var total = genders.Count;
        Response.Headers.Append("Content-Range", $"genders 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(genders);
    }
}
