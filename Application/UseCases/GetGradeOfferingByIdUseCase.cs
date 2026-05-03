using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetGradeOfferingByIdUseCase
{
    private readonly IGradeOfferingRepository _repository;

    public GetGradeOfferingByIdUseCase(IGradeOfferingRepository repository)
    {
        _repository = repository;
    }

    public async Task<GradeOfferingDTO?> ExecuteAsync(int id)
    {
        return await _repository.GetByIdAsync(id);
    }
}
