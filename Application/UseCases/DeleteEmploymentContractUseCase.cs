using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteEmploymentContractUseCase
{
    private readonly IEmploymentContractRepository _contractRepository;

    public DeleteEmploymentContractUseCase(IEmploymentContractRepository contractRepository)
    {
        _contractRepository = contractRepository;
    }

    public async Task<bool> ExecuteAsync(int id)
        => await _contractRepository.TryDeleteAsync(id);
}
