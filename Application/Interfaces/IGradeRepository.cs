using System.Text.Json;
using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IGradeRepository
{
    Task<(List<GradeDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null);
    Task<GradeDTO?> GetByIdAsync(int id);
    Task<bool> ExistsAsync(int id);
    Task<int> CreateAsync(CreateGradeDTO dto);
    Task UpdateAsync(int id, CreateGradeDTO dto);
    Task<bool> DeleteAsync(int id);
}
