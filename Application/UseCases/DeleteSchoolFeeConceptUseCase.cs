using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteSchoolFeeConceptUseCase
{
    private readonly ISchoolFeeConceptRepository _schoolFeeConceptRepository;

    public DeleteSchoolFeeConceptUseCase(ISchoolFeeConceptRepository schoolFeeConceptRepository)
    {
        _schoolFeeConceptRepository = schoolFeeConceptRepository;
    }

    public Task<bool> ExecuteAsync(int id)
        => _schoolFeeConceptRepository.DeleteAsync(id);
}
