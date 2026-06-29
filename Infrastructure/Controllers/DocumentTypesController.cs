using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

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
        Response.SetContentRange("document-types", documentTypes);
        return Ok(documentTypes);
    }
}
