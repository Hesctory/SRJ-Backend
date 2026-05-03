using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetShiftsUseCase
{
    private readonly IShiftRepository _repository;

    public GetShiftsUseCase(IShiftRepository repository)
    {
        _repository = repository;
    }

    public async Task<(List<ShiftDTO> Items, int Total)> ExecuteAsync(int skip, int take)
    {
        return await _repository.GetPagedAsync(skip, take);
    }
}
