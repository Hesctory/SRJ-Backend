using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class UpdateLunchCategoryUseCase
{
    private readonly ILunchCategoryRepository _lunchCategoryRepository;

    public UpdateLunchCategoryUseCase(ILunchCategoryRepository lunchCategoryRepository)
    {
        _lunchCategoryRepository = lunchCategoryRepository;
    }

    public async Task ExecuteAsync(int id, CreateLunchCategoryDTO dto)
    {
        if (!await _lunchCategoryRepository.ExistsAsync(id))
            throw new KeyNotFoundException();

        await _lunchCategoryRepository.UpdateAsync(id, dto);
    }
}
