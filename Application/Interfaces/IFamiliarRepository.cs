using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IFamiliarRepository
{
    Task<bool> ExistsByPersonIdAsync(int personId);
    Task CreateAsync(DFamiliar familiar, int personId);
    Task UpdateAsync(DFamiliar familiar, int personId);
    Task CreateRelationshipAsync(DFamiliar familiar, int familiarId, int studentId);
    Task<bool> TryDeleteAsync(int personId);
}
