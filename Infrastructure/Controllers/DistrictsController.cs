using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

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
        int? provinceId = null;
        if (!string.IsNullOrEmpty(filter))
        {
            var filterObj = JsonSerializer.Deserialize<JsonElement>(filter);
            if (filterObj.TryGetProperty("provinceId", out var prop) && prop.TryGetInt32(out var val))
                provinceId = val;
        }

        var districts = await _locationQueries.GetDistrictsAsync(provinceId);
        var total = districts.Count;
        Response.Headers.Append("Content-Range", $"districts 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(districts);
    }
}
