using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetSchoolFeeConceptsUseCase
{
    private readonly ISchoolFeeConceptRepository _schoolFeeConceptRepository;

    public GetSchoolFeeConceptsUseCase(ISchoolFeeConceptRepository schoolFeeConceptRepository)
    {
        _schoolFeeConceptRepository = schoolFeeConceptRepository;
    }

    public Task<(List<SchoolFeeConceptDTO> Items, int Total)> ExecuteAsync(int skip, int take)
        => _schoolFeeConceptRepository.GetPagedAsync(skip, take);
}
