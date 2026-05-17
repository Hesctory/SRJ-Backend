using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class LocationQueries : ILocationQueries
{
    private readonly SRJDbContext _context;

    public LocationQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<DepartmentDTO>> GetDepartmentsAsync(string? name = null)
    {
        var query = _context.Departments.AsNoTracking();

        if (!string.IsNullOrEmpty(name))
            query = query.Where(d => d.Name.ToLower().Contains(name.ToLower()));

        return await query
            .Select(d => new DepartmentDTO { id = d.Id, Name = d.Name, Code = d.Code })
            .ToListAsync();
    }

    public async Task<List<ProvinceDTO>> GetProvincesAsync(int? departmentId = null)
    {
        var query = _context.Provinces.AsNoTracking();

        if (departmentId.HasValue)
            query = query.Where(p => p.DepartmentId == departmentId.Value);

        return await query
            .Select(p => new ProvinceDTO { id = p.Id, Name = p.Name, Code = p.Code, DepartmentId = p.DepartmentId })
            .ToListAsync();
    }

    public async Task<List<DistrictDTO>> GetDistrictsAsync(int? provinceId = null)
    {
        var query = _context.Districts.AsNoTracking();

        if (provinceId.HasValue)
            query = query.Where(d => d.ProvinceId == provinceId.Value);

        return await query
            .Select(d => new DistrictDTO { id = d.Id, Name = d.Name, Code = d.Code, ProvinceId = d.ProvinceId })
            .ToListAsync();
    }
}
