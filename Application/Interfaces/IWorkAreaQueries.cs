using System.Text.Json;
using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IWorkAreaQueries
{
    Task<(List<WorkAreaDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null);
    Task<WorkAreaDTO?> GetByIdAsync(int id);
}
