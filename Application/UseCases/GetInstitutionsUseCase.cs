using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetInstitutionsUseCase
{
    private readonly IInstitutionRepository _institutionRepository;

    public GetInstitutionsUseCase(IInstitutionRepository institutionRepository)
    {
        _institutionRepository = institutionRepository;
    }

    public async Task<(List<InstitutionDTO> Items, int Total)> ExecuteAsync(int skip, int take)
    {
        return await _institutionRepository.GetPagedAsync(skip, take);
    }
}
