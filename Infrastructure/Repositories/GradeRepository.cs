using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class GradeRepository : IGradeRepository
{
    private readonly SRJDbContext _context;

    public GradeRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        return await _context.Grades.AnyAsync(g => g.Id == id);
    }

    public async Task<int> CreateAsync(CreateGradeDTO dto)
    {
        var grade = new Grade
        {
            LevelId = dto.LevelId,
            Name = dto.Name,
            Year = dto.Year
        };
        _context.Grades.Add(grade);
        await _context.SaveChangesAsync();
        return grade.Id;
    }

    public async Task UpdateAsync(int id, CreateGradeDTO dto)
    {
        var grade = await _context.Grades.FindAsync(id);
        grade!.LevelId = dto.LevelId;
        grade.Name = dto.Name;
        grade.Year = dto.Year;
        await _context.SaveChangesAsync();
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var grade = await _context.Grades.FindAsync(id);
        if (grade == null) return false;
        _context.Grades.Remove(grade);
        await _context.SaveChangesAsync();
        return true;
    }
}
