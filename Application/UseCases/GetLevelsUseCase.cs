using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetLevelsUseCase
{
    private readonly ILevelRepository _levelRepository;

    public GetLevelsUseCase(ILevelRepository levelRepository)
    {
        _levelRepository = levelRepository;
    }

    public async Task<(List<LevelDTO> Items, int Total)> ExecuteAsync(int skip, int take)
    {
        return await _levelRepository.GetPagedAsync(skip, take);
    }
}
