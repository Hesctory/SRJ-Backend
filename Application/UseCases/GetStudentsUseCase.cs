using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetStudentsUseCase
{
    private readonly IStudentRepository _studentRepository;

    public GetStudentsUseCase(IStudentRepository studentRepository)
    {
        _studentRepository = studentRepository;
    }

    public async Task<(List<StudentListDTO> Items, int Total)> ExecuteAsync(int skip, int take)
    {
        var (students, total) = await _studentRepository.GetPagedAsync(skip, take);
        var items = students.Select(s => new StudentListDTO
        {
            id = s.Id,
            FullName = s.FullName,
            Dni = s.IdDocumentNumber
        }).ToList();
        //Console.WriteLine(items[0].id);
        return (items, total);
    }
}
