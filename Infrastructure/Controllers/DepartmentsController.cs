using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

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
        var filters = ListRequest.ParseFilterDictionary(filter);
        var name = filters is not null && filters.TryGetValue("name", out var nameProp) ? nameProp.GetString() : null;

        var departments = await _locationQueries.GetDepartmentsAsync(name);
        Response.SetContentRange("departments", departments);
        return Ok(departments);
    }
}
