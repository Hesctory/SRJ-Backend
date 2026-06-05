using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IEmploymentContractRepository
{
    Task<int> CreateAsync(DEmploymentContract contract);
    Task UpdateAsync(DEmploymentContract contract);
    Task<DEmploymentContract?> GetByIdAsync(int id);
    Task<bool> ExistsAsync(int id);
    Task<bool> TryDeleteAsync(int id);
}
