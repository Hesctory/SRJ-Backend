using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/level-of-educations")]
public class LevelOfEducationsController : ControllerBase
{
    private readonly GetLevelOfEducationsUseCase _getLevelOfEducationsUseCase;

    public LevelOfEducationsController(GetLevelOfEducationsUseCase getLevelOfEducationsUseCase)
    {
        _getLevelOfEducationsUseCase = getLevelOfEducationsUseCase;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var levelOfEducations = await _getLevelOfEducationsUseCase.ExecuteAsync();
        var total = levelOfEducations.Count;
        Response.Headers.Append("Content-Range", $"level-of-educations 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(levelOfEducations);
    }
}
