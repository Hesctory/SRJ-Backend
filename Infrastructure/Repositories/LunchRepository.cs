using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class LunchRepository : ILunchRepository
{
    private readonly SRJDbContext _context;

    public LunchRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        return await _context.Lunches.AnyAsync(x => x.Id == id);
    }

    public async Task<int> CreateAsync(CreateLunchDTO dto)
    {
        var entity = new Lunch
        {
            LunchCategoryId = dto.LunchCategoryId,
            LunchName = dto.LunchName,
            CostPrice = dto.CostPrice,
            SalePrice = dto.SalePrice,
            Comment = dto.Comment
        };
        _context.Lunches.Add(entity);
        await _context.SaveChangesAsync();
        return entity.Id;
    }

    public async Task UpdateAsync(int id, CreateLunchDTO dto)
    {
        var entity = await _context.Lunches.FindAsync(id);
        entity!.LunchCategoryId = dto.LunchCategoryId;
        entity.LunchName = dto.LunchName;
        entity.CostPrice = dto.CostPrice;
        entity.SalePrice = dto.SalePrice;
        entity.Comment = dto.Comment;
        await _context.SaveChangesAsync();
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var entity = await _context.Lunches.FindAsync(id);
        if (entity == null) return false;
        _context.Lunches.Remove(entity);
        await _context.SaveChangesAsync();
        return true;
    }
}
