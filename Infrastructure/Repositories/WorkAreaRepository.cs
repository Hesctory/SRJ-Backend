using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class WorkAreaRepository : IWorkAreaRepository
{
    private readonly SRJDbContext _context;

    public WorkAreaRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        return await _context.WorkAreas.AnyAsync(x => x.Id == id);
    }

    public async Task<int> CreateAsync(CreateWorkAreaDTO dto)
    {
        var entity = new WorkArea
        {
            Name = dto.Name
        };
        _context.WorkAreas.Add(entity);
        await _context.SaveChangesAsync();
        return entity.Id;
    }

    public async Task UpdateAsync(int id, CreateWorkAreaDTO dto)
    {
        var entity = await _context.WorkAreas.FindAsync(id);
        entity!.Name = dto.Name;
        await _context.SaveChangesAsync();
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var entity = await _context.WorkAreas.FindAsync(id);
        if (entity == null) return false;
        _context.WorkAreas.Remove(entity);
        await _context.SaveChangesAsync();
        return true;
    }
}
