using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;

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
        var lunch = DLunch.Create(dto.LunchCategoryId, dto.LunchName!, dto.CostPrice, dto.SalePrice, dto.Comment);
        return await _lunchRepository.CreateAsync(lunch);
    }
}
