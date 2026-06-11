using System.Text.Json;
using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ILunchAssignmentQueries
{
    Task<(List<LunchAssignmentDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null);
    Task<LunchAssignmentDTO?> GetByIdAsync(int id);
    Task<(List<LunchDebtSummaryDTO> Items, int Total)> GetDebtSummariesPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null);
}
