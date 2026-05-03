using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class UpdateLevelUseCase
{
    private readonly ILevelRepository _levelRepository;

    public UpdateLevelUseCase(ILevelRepository levelRepository)
    {
        _levelRepository = levelRepository;
    }

    public async Task ExecuteAsync(int id, CreateLevelDTO dto)
    {
        if (!await _levelRepository.ExistsAsync(id))
            throw new KeyNotFoundException();

        await _levelRepository.UpdateAsync(id, dto);
    }
}
