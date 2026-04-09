using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/ethnic-self-identifications")]
public class EthnicSelfIdentificationsController : ControllerBase
{
    private readonly GetEthnicSelfIdentificationsUseCase _getEthnicSelfIdentificationsUseCase;

    public EthnicSelfIdentificationsController(GetEthnicSelfIdentificationsUseCase getEthnicSelfIdentificationsUseCase)
    {
        _getEthnicSelfIdentificationsUseCase = getEthnicSelfIdentificationsUseCase;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var ethnicSelfIdentifications = await _getEthnicSelfIdentificationsUseCase.ExecuteAsync();
        var total = ethnicSelfIdentifications.Count;
        Response.Headers.Append("Content-Range", $"ethnic-self-identifications 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(ethnicSelfIdentifications);
    }
}
