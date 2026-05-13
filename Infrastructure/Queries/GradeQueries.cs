using System.Text.Json;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Queries;

public class GradeQueries : IGradeQueries
{
    private readonly IGradeRepository _gradeRepo;

    public GradeQueries(IGradeRepository gradeRepo)
    {
        _gradeRepo = gradeRepo;
    }

    public Task<(List<GradeDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
        => _gradeRepo.GetPagedAsync(skip, take, filters);

    public Task<GradeDTO?> GetByIdAsync(int id)
        => _gradeRepo.GetByIdAsync(id);
}
