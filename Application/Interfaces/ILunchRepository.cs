using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface ILunchRepository
{
    Task<DLunch?> GetByIdAsync(int id);
    Task<int> CreateAsync(DLunch lunch);
    Task UpdateAsync(DLunch lunch);
    Task<bool> DeleteAsync(int id);
}
