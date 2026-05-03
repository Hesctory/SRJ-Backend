using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ILevelRepository
{
    Task<(List<LevelDTO> Items, int Total)> GetPagedAsync(int skip, int take);
    Task<LevelDTO?> GetByIdAsync(int id);
    Task<bool> ExistsAsync(int id);
    Task<int> CreateAsync(CreateLevelDTO dto);
    Task UpdateAsync(int id, CreateLevelDTO dto);
    Task<bool> DeleteAsync(int id);
}
