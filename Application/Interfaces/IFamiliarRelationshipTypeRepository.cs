using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IFamiliarRelationshipTypeRepository
{
    Task<List<FamiliarRelationshipTypeDTO>> GetAllAsync();
}
