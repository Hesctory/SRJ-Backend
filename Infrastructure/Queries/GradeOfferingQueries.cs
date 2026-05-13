using System.Text.Json;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Queries;

public class GradeOfferingQueries : IGradeOfferingQueries
{
    private readonly IGradeOfferingRepository _gradeOfferingRepo;

    public GradeOfferingQueries(IGradeOfferingRepository gradeOfferingRepo)
    {
        _gradeOfferingRepo = gradeOfferingRepo;
    }

    public Task<(List<GradeOfferingDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
        => _gradeOfferingRepo.GetPagedAsync(skip, take, filters);

    public Task<GradeOfferingDTO?> GetByIdAsync(int id)
        => _gradeOfferingRepo.GetByIdAsync(id);
}
