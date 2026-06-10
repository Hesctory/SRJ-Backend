using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class LunchCategoryRepository : ILunchCategoryRepository
{
    private readonly SRJDbContext _context;

    public LunchCategoryRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        return await _context.LunchCategories.AnyAsync(x => x.Id == id);
    }

    public async Task<int> CreateAsync(CreateLunchCategoryDTO dto)
    {
        var entity = new LunchCategory
        {
            Name = dto.Name
        };
        _context.LunchCategories.Add(entity);
        await _context.SaveChangesAsync();
        return entity.Id;
    }

    public async Task UpdateAsync(int id, CreateLunchCategoryDTO dto)
    {
        var entity = await _context.LunchCategories.FindAsync(id);
        entity!.Name = dto.Name;
        await _context.SaveChangesAsync();
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var entity = await _context.LunchCategories.FindAsync(id);
        if (entity == null) return false;
        _context.LunchCategories.Remove(entity);
        await _context.SaveChangesAsync();
        return true;
    }
}
