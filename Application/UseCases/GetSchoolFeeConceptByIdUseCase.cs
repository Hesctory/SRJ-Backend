using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetSchoolFeeConceptByIdUseCase
{
    private readonly ISchoolFeeConceptRepository _schoolFeeConceptRepository;

    public GetSchoolFeeConceptByIdUseCase(ISchoolFeeConceptRepository schoolFeeConceptRepository)
    {
        _schoolFeeConceptRepository = schoolFeeConceptRepository;
    }

    public Task<SchoolFeeConceptDTO?> ExecuteAsync(int id)
        => _schoolFeeConceptRepository.GetByIdAsync(id);
}
