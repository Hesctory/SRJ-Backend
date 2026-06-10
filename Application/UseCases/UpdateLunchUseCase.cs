using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class UpdateLunchUseCase
{
    private readonly ILunchRepository _lunchRepository;

    public UpdateLunchUseCase(ILunchRepository lunchRepository)
    {
        _lunchRepository = lunchRepository;
    }

    public async Task ExecuteAsync(int id, CreateLunchDTO dto)
    {
        if (!await _lunchRepository.ExistsAsync(id))
            throw new KeyNotFoundException();

        await _lunchRepository.UpdateAsync(id, dto);
    }
}
