using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class UpdateWorkAreaUseCase
{
    private readonly IWorkAreaRepository _workAreaRepository;

    public UpdateWorkAreaUseCase(IWorkAreaRepository workAreaRepository)
    {
        _workAreaRepository = workAreaRepository;
    }

    public async Task ExecuteAsync(int id, CreateWorkAreaDTO dto)
    {
        if (!await _workAreaRepository.ExistsAsync(id))
            throw new KeyNotFoundException();

        await _workAreaRepository.UpdateAsync(id, dto);
    }
}
