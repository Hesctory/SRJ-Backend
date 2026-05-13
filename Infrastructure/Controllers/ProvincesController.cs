using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

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
        int? departmentId = null;
        if (!string.IsNullOrEmpty(filter))
        {
            var filterObj = JsonSerializer.Deserialize<JsonElement>(filter);
            if (filterObj.TryGetProperty("departmentId", out var prop) && prop.TryGetInt32(out var val))
                departmentId = val;
        }

        var provinces = await _locationQueries.GetProvincesAsync(departmentId);
        var total = provinces.Count;
        Response.Headers.Append("Content-Range", $"provinces 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(provinces);
    }
}
