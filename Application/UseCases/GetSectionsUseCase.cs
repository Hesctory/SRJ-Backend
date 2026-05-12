using System.Text.Json;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetSectionsUseCase
{
    private readonly IGradeOfferingShiftSectionRepository _repository;

    public GetSectionsUseCase(IGradeOfferingShiftSectionRepository repository)
    {
        _repository = repository;
    }

    public Task<(List<SectionDTO> Items, int Total)> ExecuteAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
        => _repository.GetSectionsPagedAsync(skip, take, filters);
}
