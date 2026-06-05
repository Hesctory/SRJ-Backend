using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class JobPositionRepository : IJobPositionRepository
{
    private readonly SRJDbContext _context;

    public JobPositionRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        return await _context.JobPositions.AnyAsync(x => x.Id == id);
    }

    public async Task<int> CreateAsync(CreateJobPositionDTO dto)
    {
        var entity = new JobPosition
        {
            Name = dto.Name
        };
        _context.JobPositions.Add(entity);
        await _context.SaveChangesAsync();
        return entity.Id;
    }

    public async Task UpdateAsync(int id, CreateJobPositionDTO dto)
    {
        var entity = await _context.JobPositions.FindAsync(id);
        entity!.Name = dto.Name;
        await _context.SaveChangesAsync();
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var entity = await _context.JobPositions.FindAsync(id);
        if (entity == null) return false;
        _context.JobPositions.Remove(entity);
        await _context.SaveChangesAsync();
        return true;
    }
}
