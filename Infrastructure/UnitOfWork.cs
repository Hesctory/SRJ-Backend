using Microsoft.EntityFrameworkCore.Storage;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure;

public class UnitOfWork : IUnitOfWork
{
    private readonly SRJDbContext _context;
    private IDbContextTransaction? _transaction;

    public UnitOfWork(SRJDbContext context)
    {
        _context = context;
    }

    public async Task BeginAsync()
    {
        _transaction = await _context.Database.BeginTransactionAsync();
    }

    public async Task CommitAsync()
    {
        if (_transaction != null)
            await _transaction.CommitAsync();
    }

    public async Task RollbackAsync()
    {
        if (_transaction != null)
            await _transaction.RollbackAsync();
    }
}
