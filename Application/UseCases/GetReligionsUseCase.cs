using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetReligionsUseCase
{
    private readonly IReligionRepository _religionRepository;

    public GetReligionsUseCase(IReligionRepository religionRepository)
    {
        _religionRepository = religionRepository;
    }

    public async Task<List<ReligionDTO>> ExecuteAsync()
    {
        return await _religionRepository.GetAllAsync();
    }
}
