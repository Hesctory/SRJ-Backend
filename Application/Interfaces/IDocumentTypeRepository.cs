using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IDocumentTypeRepository
{
    Task<List<DocumentTypeDTO>> GetAllAsync();
}
