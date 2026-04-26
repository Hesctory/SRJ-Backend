using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IFamiliarRepository
{
    Task<bool> ExistsByEducationalPersonIdAsync(int educationalPersonId);
    Task CreateAsync(DFamiliar familiar, int educationalPersonId);
    Task UpdateAsync(DFamiliar familiar, int educationalPersonId);
    Task CreateRelationshipAsync(DFamiliar familiar, int familiarId, int studentId);
    Task<bool> TryDeleteAsync(int educationalPersonId);
}
