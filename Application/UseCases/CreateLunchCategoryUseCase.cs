using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class CreateLunchCategoryUseCase
{
    private readonly ILunchCategoryRepository _lunchCategoryRepository;

    public CreateLunchCategoryUseCase(ILunchCategoryRepository lunchCategoryRepository)
    {
        _lunchCategoryRepository = lunchCategoryRepository;
    }

    public async Task<int> ExecuteAsync(CreateLunchCategoryDTO dto)
    {
        return await _lunchCategoryRepository.CreateAsync(dto);
    }
}
