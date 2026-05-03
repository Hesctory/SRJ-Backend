using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetSchoolYearByIdUseCase
{
    private readonly ISchoolYearRepository _schoolYearRepository;

    public GetSchoolYearByIdUseCase(ISchoolYearRepository schoolYearRepository)
    {
        _schoolYearRepository = schoolYearRepository;
    }

    public async Task<SchoolYearDTO?> ExecuteAsync(int id)
    {
        return await _schoolYearRepository.GetByIdAsync(id);
    }
}
