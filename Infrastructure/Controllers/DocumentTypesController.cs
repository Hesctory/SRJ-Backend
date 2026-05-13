using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/document-types")]
public class DocumentTypesController : ControllerBase
{
    private readonly ILookupQueries _lookupQueries;

    public DocumentTypesController(ILookupQueries lookupQueries)
    {
        _lookupQueries = lookupQueries;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var documentTypes = await _lookupQueries.GetDocumentTypesAsync();
        var total = documentTypes.Count;
        Response.Headers.Append("Content-Range", $"document-types 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(documentTypes);
    }
}
