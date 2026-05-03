using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class UpdateGradeOfferingUseCase
{
    private readonly IGradeOfferingRepository _repository;

    public UpdateGradeOfferingUseCase(IGradeOfferingRepository repository)
    {
        _repository = repository;
    }

    public async Task ExecuteAsync(int id, CreateGradeOfferingDTO dto)
    {
        if (!await _repository.ExistsAsync(id))
            throw new KeyNotFoundException();

        await _repository.UpdateAsync(id, dto);
    }
}
