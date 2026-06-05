using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class CreateWorkAreaUseCase
{
    private readonly IWorkAreaRepository _workAreaRepository;

    public CreateWorkAreaUseCase(IWorkAreaRepository workAreaRepository)
    {
        _workAreaRepository = workAreaRepository;
    }

    public async Task<int> ExecuteAsync(CreateWorkAreaDTO dto)
    {
        return await _workAreaRepository.CreateAsync(dto);
    }
}
