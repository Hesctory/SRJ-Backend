using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetDisabilityDegreesUseCase
{
    private readonly IDisabilityDegreeRepository _disabilityDegreeRepository;

    public GetDisabilityDegreesUseCase(IDisabilityDegreeRepository disabilityDegreeRepository)
    {
        _disabilityDegreeRepository = disabilityDegreeRepository;
    }

    public async Task<List<DisabilityDegreeDTO>> ExecuteAsync()
    {
        return await _disabilityDegreeRepository.GetAllAsync();
    }
}
