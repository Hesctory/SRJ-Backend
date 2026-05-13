using System.Text.Json;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Queries;

public class ShiftQueries : IShiftQueries
{
    private readonly IShiftRepository _shiftRepo;

    public ShiftQueries(IShiftRepository shiftRepo)
    {
        _shiftRepo = shiftRepo;
    }

    public Task<(List<ShiftDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
        => _shiftRepo.GetPagedAsync(skip, take, filters);

    public Task<ShiftDTO?> GetByIdAsync(int id)
        => _shiftRepo.GetByIdAsync(id);
}
