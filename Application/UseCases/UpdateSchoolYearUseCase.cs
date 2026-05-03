using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class UpdateSchoolYearUseCase
{
    private readonly ISchoolYearRepository _schoolYearRepository;

    public UpdateSchoolYearUseCase(ISchoolYearRepository schoolYearRepository)
    {
        _schoolYearRepository = schoolYearRepository;
    }

    public async Task ExecuteAsync(int id, CreateSchoolYearDTO dto)
    {
        if (!await _schoolYearRepository.ExistsAsync(id))
            throw new KeyNotFoundException();

        if (await _schoolYearRepository.YearExistsAsync(dto.Year, excludeId: id))
            throw new InvalidOperationException("Ya existe un año escolar registrado con ese año.");

        await _schoolYearRepository.UpdateAsync(id, dto);
    }
}
