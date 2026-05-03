using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetRucStatesUseCase
{
    private readonly IRucStateRepository _rucStateRepository;

    public GetRucStatesUseCase(IRucStateRepository rucStateRepository)
    {
        _rucStateRepository = rucStateRepository;
    }

    public async Task<List<RucStateDTO>> ExecuteAsync()
    {
        return await _rucStateRepository.GetAllAsync();
    }
}
