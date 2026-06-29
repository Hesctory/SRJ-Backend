using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/districts")]
public class DistrictsController : ControllerBase
{
    private readonly ILocationQueries _locationQueries;

    public DistrictsController(ILocationQueries locationQueries)
    {
        _locationQueries = locationQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? filter = null)
    {
        var filters = ListRequest.ParseFilterDictionary(filter);
        int? provinceId = filters is not null && filters.TryGetValue("provinceId", out var prop) && prop.TryGetInt32(out var val) ? val : null;

        var districts = await _locationQueries.GetDistrictsAsync(provinceId);
        Response.SetContentRange("districts", districts);
        return Ok(districts);
    }
}
