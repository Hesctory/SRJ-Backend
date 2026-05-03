using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetGradeByIdUseCase
{
    private readonly IGradeRepository _gradeRepository;

    public GetGradeByIdUseCase(IGradeRepository gradeRepository)
    {
        _gradeRepository = gradeRepository;
    }

    public async Task<GradeDTO?> ExecuteAsync(int id)
    {
        return await _gradeRepository.GetByIdAsync(id);
    }
}
