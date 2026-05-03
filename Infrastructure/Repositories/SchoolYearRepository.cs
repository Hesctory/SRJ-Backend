using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class SchoolYearRepository : ISchoolYearRepository
{
    private readonly SRJDbContext _context;

    public SchoolYearRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<SchoolYearDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.SchoolYears.AsQueryable();

        if (filters != null)
        {
            if (filters.TryGetValue("id", out var idEl) && idEl.ValueKind == JsonValueKind.Array)
            {
                var ids = idEl.EnumerateArray()
                    .Where(e => e.TryGetInt32(out _))
                    .Select(e => e.GetInt32())
                    .ToList();
                query = query.Where(s => ids.Contains(s.Id));
            }

            if (filters.TryGetValue("year", out var yearEl) && yearEl.TryGetInt16(out var year))
                query = query.Where(s => s.Year == year);

            if (filters.TryGetValue("isActive", out var isActiveEl) && (isActiveEl.ValueKind == JsonValueKind.True || isActiveEl.ValueKind == JsonValueKind.False))
                query = query.Where(s => s.IsActive == isActiveEl.GetBoolean());
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(s => s.Year)
            .Skip(skip)
            .Take(take)
            .Select(s => new SchoolYearDTO
            {
                id = s.Id,
                Year = s.Year,
                StartDate = s.StartDate,
                EndDate = s.EndDate,
                IsActive = s.IsActive
            })
            .ToListAsync();
        return (items, total);
    }

    public async Task<SchoolYearDTO?> GetByIdAsync(int id)
    {
        return await _context.SchoolYears
            .Where(s => s.Id == id)
            .Select(s => new SchoolYearDTO
            {
                id = s.Id,
                Year = s.Year,
                StartDate = s.StartDate,
                EndDate = s.EndDate,
                IsActive = s.IsActive
            })
            .FirstOrDefaultAsync();
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

    public async Task<int> CreateAsync(CreateSchoolYearDTO dto)
    {
        var schoolYear = new SchoolYear
        {
            Year = dto.Year,
            StartDate = dto.StartDate,
            EndDate = dto.EndDate,
            IsActive = dto.IsActive
        };
        _context.SchoolYears.Add(schoolYear);
        await _context.SaveChangesAsync();
        return schoolYear.Id;
    }

    public async Task UpdateAsync(int id, CreateSchoolYearDTO dto)
    {
        var schoolYear = await _context.SchoolYears.FindAsync(id);
        schoolYear!.Year = dto.Year;
        schoolYear.StartDate = dto.StartDate;
        schoolYear.EndDate = dto.EndDate;
        schoolYear.IsActive = dto.IsActive;
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
