using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IRelationshipGuardianRepository
{
    Task<List<RelationshipGuardianDTO>> GetAllAsync();
}
