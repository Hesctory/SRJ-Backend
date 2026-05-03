using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteGradeUseCase
{
    private readonly IGradeRepository _gradeRepository;

    public DeleteGradeUseCase(IGradeRepository gradeRepository)
    {
        _gradeRepository = gradeRepository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        return await _gradeRepository.DeleteAsync(id);
    }
}
