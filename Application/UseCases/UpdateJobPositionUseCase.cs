using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class UpdateJobPositionUseCase
{
    private readonly IJobPositionRepository _jobPositionRepository;

    public UpdateJobPositionUseCase(IJobPositionRepository jobPositionRepository)
    {
        _jobPositionRepository = jobPositionRepository;
    }

    public async Task ExecuteAsync(int id, CreateJobPositionDTO dto)
    {
        if (!await _jobPositionRepository.ExistsAsync(id))
            throw new KeyNotFoundException();

        await _jobPositionRepository.UpdateAsync(id, dto);
    }
}
