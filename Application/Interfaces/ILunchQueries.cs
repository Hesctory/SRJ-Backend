using System.Text.Json;
using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ILunchQueries
{
    Task<(List<LunchDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null);
    Task<LunchDTO?> GetByIdAsync(int id);
}
