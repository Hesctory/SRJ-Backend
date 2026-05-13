using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Queries;

public class SchoolFeeConceptQueries : ISchoolFeeConceptQueries
{
    private readonly ISchoolFeeConceptRepository _schoolFeeConceptRepo;

    public SchoolFeeConceptQueries(ISchoolFeeConceptRepository schoolFeeConceptRepo)
    {
        _schoolFeeConceptRepo = schoolFeeConceptRepo;
    }

    public Task<(List<SchoolFeeConceptDTO> Items, int Total)> GetPagedAsync(int skip, int take)
        => _schoolFeeConceptRepo.GetPagedAsync(skip, take);

    public Task<SchoolFeeConceptDTO?> GetByIdAsync(int id)
        => _schoolFeeConceptRepo.GetByIdAsync(id);
}
