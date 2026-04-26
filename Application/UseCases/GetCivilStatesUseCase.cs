using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetCivilStatesUseCase
{
    private readonly ICivilStateRepository _civilStateRepository;

    public GetCivilStatesUseCase(ICivilStateRepository civilStateRepository)
    {
        _civilStateRepository = civilStateRepository;
    }

    public async Task<List<CivilStateDTO>> ExecuteAsync()
    {
        return await _civilStateRepository.GetAllAsync();
    }
}
