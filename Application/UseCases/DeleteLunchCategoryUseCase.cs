using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteLunchCategoryUseCase
{
    private readonly ILunchCategoryRepository _lunchCategoryRepository;

    public DeleteLunchCategoryUseCase(ILunchCategoryRepository lunchCategoryRepository)
    {
        _lunchCategoryRepository = lunchCategoryRepository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        return await _lunchCategoryRepository.DeleteAsync(id);
    }
}
