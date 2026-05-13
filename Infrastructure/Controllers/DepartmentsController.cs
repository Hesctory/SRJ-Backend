using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/departments")]
public class DepartmentsController : ControllerBase
{
    private readonly ILocationQueries _locationQueries;

    public DepartmentsController(ILocationQueries locationQueries)
    {
        _locationQueries = locationQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? filter = null)
    {
        string? name = null;
        if (!string.IsNullOrEmpty(filter))
        {
            var filterObj = JsonSerializer.Deserialize<JsonElement>(filter);
            if (filterObj.TryGetProperty("name", out var nameProp))
                name = nameProp.GetString();
        }

        var departments = await _locationQueries.GetDepartmentsAsync(name);
        var total = departments.Count;
        Response.Headers.Append("Content-Range", $"departments 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(departments);
    }
}
