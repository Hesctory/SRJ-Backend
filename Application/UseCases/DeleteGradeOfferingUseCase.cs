using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteGradeOfferingUseCase
{
    private readonly IGradeOfferingRepository _repository;

    public DeleteGradeOfferingUseCase(IGradeOfferingRepository repository)
    {
        _repository = repository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        return await _repository.DeleteAsync(id);
    }
}
