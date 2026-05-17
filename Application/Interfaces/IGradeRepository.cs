using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IGradeRepository
{
    Task<bool> ExistsAsync(int id);
    Task<int> CreateAsync(CreateGradeDTO dto);
    Task UpdateAsync(int id, CreateGradeDTO dto);
    Task<bool> DeleteAsync(int id);
}
