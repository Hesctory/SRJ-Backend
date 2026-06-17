using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class LunchRepository : ILunchRepository
{
    private readonly SRJDbContext _context;

    public LunchRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<DLunch?> GetByIdAsync(int id)
    {
        var entity = await _context.Lunches.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id);
        if (entity is null) return null;
        return DLunch.Reconstitute(entity.Id, entity.LunchCategoryId, entity.LunchName!, entity.CostPrice, entity.SalePrice, entity.Comment);
    }

    public async Task<int> CreateAsync(DLunch lunch)
    {
        var entity = new Lunch
        {
            LunchCategoryId = lunch.LunchCategoryId,
            LunchName = lunch.LunchName,
            CostPrice = lunch.CostPrice,
            SalePrice = lunch.SalePrice,
            Comment = lunch.Comment
        };
        _context.Lunches.Add(entity);
        await _context.SaveChangesAsync();
        return entity.Id;
    }

    public async Task UpdateAsync(DLunch lunch)
    {
        var entity = await _context.Lunches.FindAsync(lunch.Id);
        entity!.LunchCategoryId = lunch.LunchCategoryId;
        entity.LunchName = lunch.LunchName;
        entity.CostPrice = lunch.CostPrice;
        entity.SalePrice = lunch.SalePrice;
        entity.Comment = lunch.Comment;
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
