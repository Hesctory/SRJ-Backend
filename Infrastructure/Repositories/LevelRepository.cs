using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class LevelRepository : ILevelRepository
{
    private readonly SRJDbContext _context;

    public LevelRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        return await _context.Levels.AnyAsync(l => l.Id == id);
    }

    public async Task<int> CreateAsync(CreateLevelDTO dto)
    {
        var level = new Level
        {
            Name = dto.Name,
            OrderIndex = dto.OrderIndex
        };
        _context.Levels.Add(level);
        await _context.SaveChangesAsync();
        return level.Id;
    }

    public async Task UpdateAsync(int id, CreateLevelDTO dto)
    {
        var level = await _context.Levels.FindAsync(id);
        level!.Name = dto.Name;
        level.OrderIndex = dto.OrderIndex;
        await _context.SaveChangesAsync();
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var level = await _context.Levels.FindAsync(id);
        if (level == null) return false;
        _context.Levels.Remove(level);
        await _context.SaveChangesAsync();
        return true;
    }
}
