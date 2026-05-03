using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetLevelByIdUseCase
{
    private readonly ILevelRepository _levelRepository;

    public GetLevelByIdUseCase(ILevelRepository levelRepository)
    {
        _levelRepository = levelRepository;
    }

    public async Task<LevelDTO?> ExecuteAsync(int id)
    {
        return await _levelRepository.GetByIdAsync(id);
    }
}
