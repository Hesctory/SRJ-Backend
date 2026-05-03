using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class CreateGradeOfferingUseCase
{
    private readonly IGradeOfferingRepository _repository;
    private readonly IGradeOfferingShiftSectionRepository _sectionRepository;

    public CreateGradeOfferingUseCase(
        IGradeOfferingRepository repository,
        IGradeOfferingShiftSectionRepository sectionRepository)
    {
        _repository = repository;
        _sectionRepository = sectionRepository;
    }

    public async Task<int> ExecuteAsync(CreateGradeOfferingDTO dto)
    {
        var id = await _repository.CreateAsync(dto);
        await _sectionRepository.AddRangeAsync(id, 1, dto.Sections);
        return id;
    }
}
