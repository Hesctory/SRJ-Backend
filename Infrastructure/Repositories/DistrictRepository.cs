using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class DistrictRepository : IDistrictRepository
{
    private readonly SRJDbContext _context;

    public DistrictRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<DistrictDTO>> GetAllAsync(int? provinceId = null)
    {
        var query = _context.Districts.AsQueryable();

        if (provinceId.HasValue)
            query = query.Where(d => d.ProvinceId == provinceId.Value);

        return await query
            .Select(d => new DistrictDTO { id = d.Id, Name = d.Name, Code = d.Code, ProvinceId = d.ProvinceId })
            .ToListAsync();
    }
}
