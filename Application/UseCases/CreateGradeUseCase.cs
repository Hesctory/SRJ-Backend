using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class CreateGradeUseCase
{
    private readonly IGradeRepository _gradeRepository;

    public CreateGradeUseCase(IGradeRepository gradeRepository)
    {
        _gradeRepository = gradeRepository;
    }

    public async Task<int> ExecuteAsync(CreateGradeDTO dto)
    {
        return await _gradeRepository.CreateAsync(dto);
    }
}
