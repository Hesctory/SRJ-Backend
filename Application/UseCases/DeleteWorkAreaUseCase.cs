using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteWorkAreaUseCase
{
    private readonly IWorkAreaRepository _workAreaRepository;

    public DeleteWorkAreaUseCase(IWorkAreaRepository workAreaRepository)
    {
        _workAreaRepository = workAreaRepository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        return await _workAreaRepository.DeleteAsync(id);
    }
}
