using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/document-types")]
public class DocumentTypesController : ControllerBase
{
    private readonly GetDocumentTypesUseCase _getDocumentTypesUseCase;

    public DocumentTypesController(GetDocumentTypesUseCase getDocumentTypesUseCase)
    {
        _getDocumentTypesUseCase = getDocumentTypesUseCase;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var documentTypes = await _getDocumentTypesUseCase.ExecuteAsync();
        var total = documentTypes.Count;
        Response.Headers.Append("Content-Range", $"document-types 0-{(total == 0 ? 0 : total - 1)}/{total}");
        return Ok(documentTypes);
    }
}
