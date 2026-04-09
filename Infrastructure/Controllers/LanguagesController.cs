using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/languages")]
public class LanguagesController : ControllerBase
{
    private readonly GetLanguagesUseCase _getLanguagesUseCase;

    public LanguagesController(GetLanguagesUseCase getLanguagesUseCase)
    {
        _getLanguagesUseCase = getLanguagesUseCase;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var languages = await _getLanguagesUseCase.ExecuteAsync();
        var total = languages.Count;
        Response.Headers.Append("Content-Range", $"languages 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(languages);
    }
}
