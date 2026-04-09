using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetDocumentTypesUseCase
{
    private readonly IDocumentTypeRepository _documentTypeRepository;

    public GetDocumentTypesUseCase(IDocumentTypeRepository documentTypeRepository)
    {
        _documentTypeRepository = documentTypeRepository;
    }

    public async Task<List<DocumentTypeDTO>> ExecuteAsync()
    {
        return await _documentTypeRepository.GetAllAsync();
    }
}
