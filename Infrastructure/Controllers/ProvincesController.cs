using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/provinces")]
public class ProvincesController : ControllerBase
{
    private readonly ILocationQueries _locationQueries;

    public ProvincesController(ILocationQueries locationQueries)
    {
        _locationQueries = locationQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? filter = null)
    {
        var filters = ListRequest.ParseFilterDictionary(filter);
        int? departmentId = filters is not null && filters.TryGetValue("departmentId", out var prop) && prop.TryGetInt32(out var val) ? val : null;

        var provinces = await _locationQueries.GetProvincesAsync(departmentId);
        Response.SetContentRange("provinces", provinces);
        return Ok(provinces);
    }
}
