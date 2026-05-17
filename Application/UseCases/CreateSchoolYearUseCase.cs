using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.UseCases;

public class CreateSchoolYearUseCase
{
    private readonly ISchoolYearRepository _schoolYearRepository;

    public CreateSchoolYearUseCase(ISchoolYearRepository schoolYearRepository)
    {
        _schoolYearRepository = schoolYearRepository;
    }

    public async Task<int> ExecuteAsync(CreateSchoolYearDTO dto)
    {
        if (await _schoolYearRepository.YearExistsAsync(dto.Year))
            throw new InvalidOperationException("Ya existe un año escolar registrado con ese año.");

        var schoolYear = DSchoolYear.Create(0, dto.Year, dto.StartDate, dto.EndDate, dto.IsActive ?? false);
        return await _schoolYearRepository.CreateAsync(schoolYear);
    }
}
