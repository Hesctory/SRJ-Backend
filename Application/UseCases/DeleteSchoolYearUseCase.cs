using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteSchoolYearUseCase
{
    private readonly ISchoolYearRepository _schoolYearRepository;

    public DeleteSchoolYearUseCase(ISchoolYearRepository schoolYearRepository)
    {
        _schoolYearRepository = schoolYearRepository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        return await _schoolYearRepository.DeleteAsync(id);
    }
}
