using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class ProvinceRepository : IProvinceRepository
{
    private readonly SRJDbContext _context;

    public ProvinceRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<ProvinceDTO>> GetAllAsync(int? departmentId = null)
    {
        var query = _context.Provinces.AsQueryable();

        if (departmentId.HasValue)
            query = query.Where(p => p.DepartmentId == departmentId.Value);

        return await query
            .Select(p => new ProvinceDTO { id = p.Id, Name = p.Name, Code = p.Code, DepartmentId = p.DepartmentId })
            .ToListAsync();
    }
}
