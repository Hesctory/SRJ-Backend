using System.Text.Json;
using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ISchoolYearQueries
{
    Task<(List<SchoolYearDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null);
    Task<SchoolYearDTO?> GetByIdAsync(int id);
}
