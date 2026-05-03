using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

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

        return await _schoolYearRepository.CreateAsync(dto);
    }
}
