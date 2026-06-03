using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class UpdateAccountUseCase
{
    private readonly IAccountRepository _repository;

    public UpdateAccountUseCase(IAccountRepository repository)
    {
        _repository = repository;
    }

    public async Task ExecuteAsync(int id, CreateAccountDTO dto)
    {
        if (!await _repository.ExistsAsync(id))
            throw new KeyNotFoundException();

        await _repository.UpdateAsync(id, dto);
    }
}
