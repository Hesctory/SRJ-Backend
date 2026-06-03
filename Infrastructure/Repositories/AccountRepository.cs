using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class AccountRepository : IAccountRepository
{
    private readonly SRJDbContext _context;

    public AccountRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        return await _context.Accounts.AnyAsync(a => a.Id == id);
    }

    public async Task<int> CreateAsync(CreateAccountDTO dto)
    {
        var account = new Account
        {
            Code = dto.Code,
            Name = dto.Name,
            ParentAccountId = dto.ParentAccountId,
            PrintCode = dto.PrintCode
        };
        _context.Accounts.Add(account);
        await _context.SaveChangesAsync();
        return account.Id;
    }

    public async Task UpdateAsync(int id, CreateAccountDTO dto)
    {
        var account = await _context.Accounts.FindAsync(id);
        account!.Code = dto.Code;
        account.Name = dto.Name;
        account.ParentAccountId = dto.ParentAccountId;
        account.PrintCode = dto.PrintCode;
        await _context.SaveChangesAsync();
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var account = await _context.Accounts.FindAsync(id);
        if (account == null) return false;
        _context.Accounts.Remove(account);
        await _context.SaveChangesAsync();
        return true;
    }
}
