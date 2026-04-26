using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetLevelOfEducationsUseCase
{
    private readonly ILevelOfEducationRepository _levelOfEducationRepository;

    public GetLevelOfEducationsUseCase(ILevelOfEducationRepository levelOfEducationRepository)
    {
        _levelOfEducationRepository = levelOfEducationRepository;
    }

    public async Task<List<LevelOfEducationDTO>> ExecuteAsync()
    {
        return await _levelOfEducationRepository.GetAllAsync();
    }
}
