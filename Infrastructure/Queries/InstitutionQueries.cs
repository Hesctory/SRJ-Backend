using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class InstitutionQueries : IInstitutionQueries
{
    private readonly SRJDbContext _context;

    public InstitutionQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<InstitutionDTO> Items, int Total)> GetPagedAsync(int skip, int take)
    {
        var query = _context.Institutions.AsNoTracking();
        var total = await query.CountAsync();
        var items = await query
            .OrderBy(i => i.Id)
            .Skip(skip)
            .Take(take)
            .Select(i => new InstitutionDTO
            {
                id = i.Id,
                Name = i.Name,
                Ruc = i.Ruc,
                RucStateId = i.RucStateId
            })
            .ToListAsync();
        return (items, total);
    }

    public async Task<InstitutionDTO?> GetByIdAsync(int id)
    {
        return await _context.Institutions
            .AsNoTracking()
            .Where(i => i.Id == id)
            .Select(i => new InstitutionDTO
            {
                id = i.Id,
                Name = i.Name,
                Ruc = i.Ruc,
                RucStateId = i.RucStateId
            })
            .FirstOrDefaultAsync();
    }
}
