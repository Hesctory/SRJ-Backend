using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetDisabilityTypesUseCase
{
    private readonly IDisabilityTypeRepository _disabilityTypeRepository;

    public GetDisabilityTypesUseCase(IDisabilityTypeRepository disabilityTypeRepository)
    {
        _disabilityTypeRepository = disabilityTypeRepository;
    }

    public async Task<List<DisabilityTypeDTO>> ExecuteAsync()
    {
        return await _disabilityTypeRepository.GetAllAsync();
    }
}
