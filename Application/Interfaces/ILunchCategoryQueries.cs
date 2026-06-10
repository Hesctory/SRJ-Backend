using System.Text.Json;
using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ILunchCategoryQueries
{
    Task<(List<LunchCategoryDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null);
    Task<LunchCategoryDTO?> GetByIdAsync(int id);
}
