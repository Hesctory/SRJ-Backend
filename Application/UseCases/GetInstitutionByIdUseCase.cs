using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetInstitutionByIdUseCase
{
    private readonly IInstitutionRepository _institutionRepository;

    public GetInstitutionByIdUseCase(IInstitutionRepository institutionRepository)
    {
        _institutionRepository = institutionRepository;
    }

    public async Task<InstitutionDTO?> ExecuteAsync(int id)
    {
        return await _institutionRepository.GetByIdAsync(id);
    }
}
