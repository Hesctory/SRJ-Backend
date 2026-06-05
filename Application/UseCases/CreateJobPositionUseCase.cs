using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class CreateJobPositionUseCase
{
    private readonly IJobPositionRepository _jobPositionRepository;

    public CreateJobPositionUseCase(IJobPositionRepository jobPositionRepository)
    {
        _jobPositionRepository = jobPositionRepository;
    }

    public async Task<int> ExecuteAsync(CreateJobPositionDTO dto)
    {
        return await _jobPositionRepository.CreateAsync(dto);
    }
}
