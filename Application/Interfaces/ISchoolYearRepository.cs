using System.Text.Json;
using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ISchoolYearRepository
{
    Task<(List<SchoolYearDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null);
    Task<SchoolYearDTO?> GetByIdAsync(int id);
    Task<bool> ExistsAsync(int id);
    Task<bool> YearExistsAsync(short year, int? excludeId = null);
    Task<int> CreateAsync(CreateSchoolYearDTO dto);
    Task UpdateAsync(int id, CreateSchoolYearDTO dto);
    Task<bool> DeleteAsync(int id);
    Task<bool> IsOpenAsync(int id);
}