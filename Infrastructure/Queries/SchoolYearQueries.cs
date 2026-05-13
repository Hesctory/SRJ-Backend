using System.Text.Json;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Queries;

public class SchoolYearQueries : ISchoolYearQueries
{
    private readonly ISchoolYearRepository _schoolYearRepo;

    public SchoolYearQueries(ISchoolYearRepository schoolYearRepo)
    {
        _schoolYearRepo = schoolYearRepo;
    }

    public Task<(List<SchoolYearDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
        => _schoolYearRepo.GetPagedAsync(skip, take, filters);

    public Task<SchoolYearDTO?> GetByIdAsync(int id)
        => _schoolYearRepo.GetByIdAsync(id);
}
