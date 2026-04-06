using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.UseCases;

public class GetStudentByIdUseCase
{
    private readonly IStudentRepository _studentRepository;

    public GetStudentByIdUseCase(IStudentRepository studentRepository)
    {
        _studentRepository = studentRepository;
    }

    public Task<DStudent?> ExecuteAsync(int id) => _studentRepository.GetByIdAsync(id);
}
