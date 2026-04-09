using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class StudentRepository : IStudentRepository
{
    private readonly SRJDbContext _context;

    public StudentRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<DStudent> Items, int Total)> GetPagedAsync(int skip, int take)
    {
        var query = _context.Students
            .Include(s => s.EducationalPerson)
                .ThenInclude(ep => ep.Person)
                    .ThenInclude(p => p.Gender)
            .Include(s => s.EducationalPerson)
                .ThenInclude(ep => ep.Person)
                    .ThenInclude(p => p.DocumentType);

        var total = await query.CountAsync();
        var students = await query.Skip(skip).Take(take).ToListAsync();

        return (students.Select(MapToDomain).ToList(), total);
    }

    public async Task<DStudent?> GetByIdAsync(int id)
    {
        var student = await _context.Students
            .Include(s => s.EducationalPerson)
                .ThenInclude(ep => ep.Person)
                    .ThenInclude(p => p.Gender)
            .Include(s => s.EducationalPerson)
                .ThenInclude(ep => ep.Person)
                    .ThenInclude(p => p.DocumentType)
            .FirstOrDefaultAsync(s => s.EducationalPersonId == id);

        return student == null ? null : MapToDomain(student);
    }

    private static DStudent MapToDomain(Student s)
    {
        var person = s.EducationalPerson.Person;
        var fullName = $"{person.Names} {person.PaternalLastname} {person.MaternalLastname}".Trim();

        return new DStudent(
            id: s.EducationalPersonId,
            studentCode: s.StudentCode,
            fullName: fullName,
            birthDate: person.BirthDate,
            gender: person.Gender?.Name,
            documentType: person.DocumentType?.Name,
            idDocumentNumber: person.IdDocumentNumber,
            email: person.Email,
            cellPhone: person.CellPhone,
            hasDisability: s.HasDisability
        );
    }
}
