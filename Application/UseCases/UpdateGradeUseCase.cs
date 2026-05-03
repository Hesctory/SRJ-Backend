using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class UpdateGradeUseCase
{
    private readonly IGradeRepository _gradeRepository;

    public UpdateGradeUseCase(IGradeRepository gradeRepository)
    {
        _gradeRepository = gradeRepository;
    }

    public async Task ExecuteAsync(int id, CreateGradeDTO dto)
    {
        if (!await _gradeRepository.ExistsAsync(id))
            throw new KeyNotFoundException();

        await _gradeRepository.UpdateAsync(id, dto);
    }
}
