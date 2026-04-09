using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class DepartmentRepository : IDepartmentRepository
{
    private readonly SRJDbContext _context;

    public DepartmentRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<DepartmentDTO>> GetAllAsync(string? name = null)
    {
        var query = _context.Departments.AsQueryable();

        if (!string.IsNullOrEmpty(name))
            query = query.Where(d => d.Name.ToLower().Contains(name.ToLower()));

        return await query
            .Select(d => new DepartmentDTO { id = d.Id, Name = d.Name, Code = d.Code })
            .ToListAsync();
    }
}
