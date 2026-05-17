using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class SchoolYearRepository : ISchoolYearRepository
{
    private readonly SRJDbContext _context;

    public SchoolYearRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        return await _context.SchoolYears.AnyAsync(s => s.Id == id);
    }

    public async Task<bool> YearExistsAsync(short year, int? excludeId = null)
    {
        return await _context.SchoolYears
            .AnyAsync(s => s.Year == year && (excludeId == null || s.Id != excludeId));
    }

    public async Task<DSchoolYear?> FindByIdAsync(int id)
    {
        var sy = await _context.SchoolYears.FindAsync(id);
        return sy == null ? null : DSchoolYear.Reconstitute(sy.Id, sy.Year, sy.StartDate, sy.EndDate, sy.IsActive == true);
    }

    public async Task<int> CreateAsync(DSchoolYear schoolYear)
    {
        var entity = new SchoolYear
        {
            Year = schoolYear.Year,
            StartDate = schoolYear.StartDate,
            EndDate = schoolYear.EndDate,
            IsActive = schoolYear.IsActive
        };
        _context.SchoolYears.Add(entity);
        await _context.SaveChangesAsync();
        return entity.Id;
    }

    public async Task UpdateAsync(DSchoolYear schoolYear)
    {
        var entity = await _context.SchoolYears.FindAsync(schoolYear.Id);
        entity!.Year = schoolYear.Year;
        entity.StartDate = schoolYear.StartDate;
        entity.EndDate = schoolYear.EndDate;
        entity.IsActive = schoolYear.IsActive;
        await _context.SaveChangesAsync();
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var schoolYear = await _context.SchoolYears.FindAsync(id);
        if (schoolYear == null) return false;
        _context.SchoolYears.Remove(schoolYear);
        await _context.SaveChangesAsync();
        return true;
    }
}
