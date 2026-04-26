using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetFamiliarRelationshipTypesUseCase
{
    private readonly IFamiliarRelationshipTypeRepository _familiarRelationshipTypeRepository;

    public GetFamiliarRelationshipTypesUseCase(IFamiliarRelationshipTypeRepository familiarRelationshipTypeRepository)
    {
        _familiarRelationshipTypeRepository = familiarRelationshipTypeRepository;
    }

    public async Task<List<FamiliarRelationshipTypeDTO>> ExecuteAsync()
    {
        return await _familiarRelationshipTypeRepository.GetAllAsync();
    }
}
