using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class CreateAccountUseCase
{
    private readonly IAccountRepository _repository;

    public CreateAccountUseCase(IAccountRepository repository)
    {
        _repository = repository;
    }

    public async Task<int> ExecuteAsync(CreateAccountDTO dto)
    {
        return await _repository.CreateAsync(dto);
    }
}
