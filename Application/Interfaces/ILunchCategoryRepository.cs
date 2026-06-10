using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ILunchCategoryRepository
{
    Task<bool> ExistsAsync(int id);
    Task<int> CreateAsync(CreateLunchCategoryDTO dto);
    Task UpdateAsync(int id, CreateLunchCategoryDTO dto);
    Task<bool> DeleteAsync(int id);
}
