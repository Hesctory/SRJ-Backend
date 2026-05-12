using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class CreateGradeOfferingUseCase
{
    private readonly IGradeOfferingRepository _repository;

    public CreateGradeOfferingUseCase(IGradeOfferingRepository repository)
    {
        _repository = repository;
    }

    public Task<int> ExecuteAsync(CreateGradeOfferingDTO dto)
        => _repository.CreateAsync(dto);
}
