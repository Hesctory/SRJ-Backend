using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetGendersUseCase
{
    private readonly IGenderRepository _genderRepository;

    public GetGendersUseCase(IGenderRepository genderRepository)
    {
        _genderRepository = genderRepository;
    }

    public async Task<List<GenderDTO>> ExecuteAsync()
    {
        return await _genderRepository.GetAllAsync();
    }
}
