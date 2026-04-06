using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.UseCases;

public class GetStudentsUseCase
{
    private readonly IStudentRepository _studentRepository;

    public GetStudentsUseCase(IStudentRepository studentRepository)
    {
        _studentRepository = studentRepository;
    }

    public Task<List<DStudent>> ExecuteAsync() => _studentRepository.GetAllAsync();
}
