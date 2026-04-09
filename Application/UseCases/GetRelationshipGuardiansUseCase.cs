using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetRelationshipGuardiansUseCase
{
    private readonly IRelationshipGuardianRepository _relationshipGuardianRepository;

    public GetRelationshipGuardiansUseCase(IRelationshipGuardianRepository relationshipGuardianRepository)
    {
        _relationshipGuardianRepository = relationshipGuardianRepository;
    }

    public async Task<List<RelationshipGuardianDTO>> ExecuteAsync()
    {
        return await _relationshipGuardianRepository.GetAllAsync();
    }
}
