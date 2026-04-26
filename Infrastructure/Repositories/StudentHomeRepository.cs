using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class StudentHomeRepository : IStudentHomeRepository
{
    private readonly SRJDbContext _context;

    public StudentHomeRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<StudentHome?> GetByStudentIdAsync(int studentId) =>
        await _context.StudentHomes.FirstOrDefaultAsync(sh => sh.StudentId == studentId);

    public async Task CreateAsync(StudentHome studentHome)
    {
        _context.StudentHomes.Add(studentHome);
        await _context.SaveChangesAsync();
    }

    public async Task<bool> ExistsAsync(int studentId) =>
        await _context.StudentHomes.AnyAsync(sh => sh.StudentId == studentId);

    public async Task DeleteAsync(int studentId)
    {
        var studentHome = await _context.StudentHomes.FindAsync(studentId);
        _context.StudentHomes.Remove(studentHome!);
        await _context.SaveChangesAsync();
    }
}
