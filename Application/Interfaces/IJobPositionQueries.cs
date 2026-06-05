using System.Text.Json;
using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IJobPositionQueries
{
    Task<(List<JobPositionDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null);
    Task<JobPositionDTO?> GetByIdAsync(int id);
}
