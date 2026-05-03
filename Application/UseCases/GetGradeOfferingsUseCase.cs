using System.Text.Json;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetGradeOfferingsUseCase
{
    private readonly IGradeOfferingRepository _repository;

    public GetGradeOfferingsUseCase(IGradeOfferingRepository repository)
    {
        _repository = repository;
    }

    public async Task<(List<GradeOfferingDTO> Items, int Total)> ExecuteAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        return await _repository.GetPagedAsync(skip, take, filters);
    }
}
