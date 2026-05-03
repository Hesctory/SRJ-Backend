using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteLevelUseCase
{
    private readonly ILevelRepository _levelRepository;

    public DeleteLevelUseCase(ILevelRepository levelRepository)
    {
        _levelRepository = levelRepository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        return await _levelRepository.DeleteAsync(id);
    }
}
