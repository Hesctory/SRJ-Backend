using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class SchoolFeeConceptQueries : ISchoolFeeConceptQueries
{
    private readonly SRJDbContext _context;

    public SchoolFeeConceptQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<SchoolFeeConceptDTO> Items, int Total)> GetPagedAsync(int skip, int take)
    {
        var query = _context.SchoolFeeConcepts.AsNoTracking();
        var total = await query.CountAsync();
        var items = await query
            .OrderBy(s => s.Id)
            .Skip(skip)
            .Take(take)
            .Select(s => new SchoolFeeConceptDTO { id = s.Id, Name = s.Name })
            .ToListAsync();
        return (items, total);
    }

    public async Task<SchoolFeeConceptDTO?> GetByIdAsync(int id)
    {
        return await _context.SchoolFeeConcepts
            .AsNoTracking()
            .Where(s => s.Id == id)
            .Select(s => new SchoolFeeConceptDTO { id = s.Id, Name = s.Name })
            .FirstOrDefaultAsync();
    }
}
