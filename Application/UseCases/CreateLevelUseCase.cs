using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class CreateLevelUseCase
{
    private readonly ILevelRepository _levelRepository;

    public CreateLevelUseCase(ILevelRepository levelRepository)
    {
        _levelRepository = levelRepository;
    }

    public async Task<int> ExecuteAsync(CreateLevelDTO dto)
    {
        return await _levelRepository.CreateAsync(dto);
    }
}
