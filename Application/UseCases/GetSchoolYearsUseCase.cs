using System.Text.Json;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetSchoolYearsUseCase
{
    private readonly ISchoolYearRepository _schoolYearRepository;

    public GetSchoolYearsUseCase(ISchoolYearRepository schoolYearRepository)
    {
        _schoolYearRepository = schoolYearRepository;
    }

    public async Task<(List<SchoolYearDTO> Items, int Total)> ExecuteAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        return await _schoolYearRepository.GetPagedAsync(skip, take, filters);
    }
}
