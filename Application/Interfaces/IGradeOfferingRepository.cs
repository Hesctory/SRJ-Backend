using System.Text.Json;
using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IGradeOfferingRepository
{
    Task<(List<GradeOfferingDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null);
    Task<GradeOfferingDTO?> GetByIdAsync(int id);
    Task<bool> ExistsAsync(int id);
    Task<int> CreateAsync(CreateGradeOfferingDTO dto);
    Task UpdateAsync(int id, CreateGradeOfferingDTO dto);
    Task<bool> DeleteAsync(int id);
}
