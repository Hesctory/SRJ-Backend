namespace SRJBackend.Application.Interfaces;

public interface IUnitOfWork
{
    Task BeginAsync();
    Task CommitAsync();
    Task RollbackAsync();
}
