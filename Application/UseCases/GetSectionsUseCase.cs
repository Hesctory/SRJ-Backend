using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetSectionsUseCase
{
    private readonly IGradeOfferingShiftSectionRepository _sectionRepository;

    public GetSectionsUseCase(IGradeOfferingShiftSectionRepository sectionRepository)
    {
        _sectionRepository = sectionRepository;
    }

    public async Task<List<SectionDTO>> ExecuteAsync(int? gradeOfferingShiftId = null)
    {
        var sections = await _sectionRepository.GetAllAsync(gradeOfferingShiftId);
        return sections;
    }
}