using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetShiftByIdUseCase
{
    private readonly IShiftRepository _repository;

    public GetShiftByIdUseCase(IShiftRepository repository)
    {
        _repository = repository;
    }

    public async Task<ShiftDTO?> ExecuteAsync(int id)
    {
        return await _repository.GetByIdAsync(id);
    }
}
