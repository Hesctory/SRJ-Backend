using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ILevelRepository
{
    Task<bool> ExistsAsync(int id);
    Task<int> CreateAsync(CreateLevelDTO dto);
    Task UpdateAsync(int id, CreateLevelDTO dto);
    Task<bool> DeleteAsync(int id);
}
