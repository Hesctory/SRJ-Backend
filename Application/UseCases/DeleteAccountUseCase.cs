using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteAccountUseCase
{
    private readonly IAccountRepository _repository;

    public DeleteAccountUseCase(IAccountRepository repository)
    {
        _repository = repository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        return await _repository.DeleteAsync(id);
    }
}
