using System.Text.Json;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Queries;

public class SectionQueries : ISectionQueries
{
    private readonly IGradeOfferingShiftSectionRepository _sectionRepo;

    public SectionQueries(IGradeOfferingShiftSectionRepository sectionRepo)
    {
        _sectionRepo = sectionRepo;
    }

    public Task<(List<SectionDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
        => _sectionRepo.GetSectionsPagedAsync(skip, take, filters);
}
