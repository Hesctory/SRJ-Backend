using System.Text.Json;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetGradesUseCase
{
    private readonly IGradeRepository _gradeRepository;

    public GetGradesUseCase(IGradeRepository gradeRepository)
    {
        _gradeRepository = gradeRepository;
    }

    public async Task<(List<GradeDTO> Items, int Total)> ExecuteAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        return await _gradeRepository.GetPagedAsync(skip, take, filters);
    }
}
