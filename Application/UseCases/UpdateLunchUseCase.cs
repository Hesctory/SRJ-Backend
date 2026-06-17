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
        var lunch = await _lunchRepository.GetByIdAsync(id)
            ?? throw new KeyNotFoundException();

        lunch.Update(dto.LunchCategoryId, dto.LunchName!, dto.CostPrice, dto.SalePrice, dto.Comment);
        await _lunchRepository.UpdateAsync(lunch);
    }
}
