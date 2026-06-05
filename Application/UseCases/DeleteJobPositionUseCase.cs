using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteJobPositionUseCase
{
    private readonly IJobPositionRepository _jobPositionRepository;

    public DeleteJobPositionUseCase(IJobPositionRepository jobPositionRepository)
    {
        _jobPositionRepository = jobPositionRepository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        return await _jobPositionRepository.DeleteAsync(id);
    }
}
