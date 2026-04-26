using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/childbirth-types")]
public class ChildbirthTypesController : ControllerBase
{
    private readonly GetChildbirthTypesUseCase _getChildbirthTypesUseCase;

    public ChildbirthTypesController(GetChildbirthTypesUseCase getChildbirthTypesUseCase)
    {
        _getChildbirthTypesUseCase = getChildbirthTypesUseCase;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var childbirthTypes = await _getChildbirthTypesUseCase.ExecuteAsync();
        var total = childbirthTypes.Count;
        Response.Headers.Append("Content-Range", $"childbirth-types 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(childbirthTypes);
    }
}
