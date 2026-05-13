using System.Text.Json;
using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IGradeOfferingQueries
{
    Task<(List<GradeOfferingDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null);
    Task<GradeOfferingDTO?> GetByIdAsync(int id);
}
