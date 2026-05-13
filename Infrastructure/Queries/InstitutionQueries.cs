using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Queries;

public class InstitutionQueries : IInstitutionQueries
{
    private readonly IInstitutionRepository _institutionRepo;

    public InstitutionQueries(IInstitutionRepository institutionRepo)
    {
        _institutionRepo = institutionRepo;
    }

    public Task<(List<InstitutionDTO> Items, int Total)> GetPagedAsync(int skip, int take)
        => _institutionRepo.GetPagedAsync(skip, take);

    public Task<InstitutionDTO?> GetByIdAsync(int id)
        => _institutionRepo.GetByIdAsync(id);
}
