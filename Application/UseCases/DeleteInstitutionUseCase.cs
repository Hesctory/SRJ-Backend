using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteInstitutionUseCase
{
    private readonly IInstitutionRepository _institutionRepository;

    public DeleteInstitutionUseCase(IInstitutionRepository institutionRepository)
    {
        _institutionRepository = institutionRepository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        return await _institutionRepository.DeleteAsync(id);
    }
}
