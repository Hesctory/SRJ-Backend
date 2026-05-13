using System.Text.Json;
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

    public async Task<(List<GradeDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.Grades.AsQueryable();

        if (filters != null)
        {
            if (filters.TryGetValue("levelId", out var levelIdEl) && levelIdEl.TryGetInt32(out var levelId))
                query = query.Where(g => g.LevelId == levelId);

            if (filters.TryGetValue("name", out var nameEl) && nameEl.GetString() is string name)
                query = query.Where(g => g.Name.ToLower().Contains(name.ToLower()));

            if (filters.TryGetValue("year", out var yearEl) && yearEl.TryGetInt32(out var year))
                query = query.Where(g => g.Year == year);

            if (filters.TryGetValue("id", out var idEl) && idEl.ValueKind == JsonValueKind.Array)
            {
                var ids = idEl.EnumerateArray()
                    .Where(e => e.TryGetInt32(out _))
                    .Select(e => e.GetInt32())
                    .ToList();
                query = query.Where(g => ids.Contains(g.Id));
            }

            int? schoolYearId = filters.TryGetValue("schoolYearId", out var syEl) && syEl.TryGetInt32(out var sy) ? sy : null;

            if (schoolYearId.HasValue)
            {
                query = query.Where(s => s.GradeOfferings.Any(gos =>
                    (!schoolYearId.HasValue || gos.SchoolYearId == schoolYearId.Value)
                ));
            }            
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(g => g.LevelId)
            .ThenBy(g => g.Year)
            .Skip(skip)
            .Take(take)
            .Select(g => new GradeDTO
            {
                id = g.Id,
                LevelId = g.LevelId,
                Name = g.Name,
                Year = g.Year
            })
            .ToListAsync();
        return (items, total);
    }

    public async Task<GradeDTO?> GetByIdAsync(int id)
    {
        return await _context.Grades
            .Where(g => g.Id == id)
            .Select(g => new GradeDTO
            {
                id = g.Id,
                LevelId = g.LevelId,
                Name = g.Name,
                Year = g.Year
            })
            .FirstOrDefaultAsync();
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
