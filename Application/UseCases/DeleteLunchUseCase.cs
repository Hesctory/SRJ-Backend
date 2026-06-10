using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteLunchUseCase
{
    private readonly ILunchRepository _lunchRepository;

    public DeleteLunchUseCase(ILunchRepository lunchRepository)
    {
        _lunchRepository = lunchRepository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        return await _lunchRepository.DeleteAsync(id);
    }
}
