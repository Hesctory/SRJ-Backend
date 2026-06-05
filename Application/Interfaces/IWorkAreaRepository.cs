using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IWorkAreaRepository
{
    Task<bool> ExistsAsync(int id);
    Task<int> CreateAsync(CreateWorkAreaDTO dto);
    Task UpdateAsync(int id, CreateWorkAreaDTO dto);
    Task<bool> DeleteAsync(int id);
}
