using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class CreateLunchUseCase
{
    private readonly ILunchRepository _lunchRepository;

    public CreateLunchUseCase(ILunchRepository lunchRepository)
    {
        _lunchRepository = lunchRepository;
    }

    public async Task<int> ExecuteAsync(CreateLunchDTO dto)
    {
        return await _lunchRepository.CreateAsync(dto);
    }
}
